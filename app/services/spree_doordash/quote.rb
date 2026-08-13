module SpreeDoordash
  # Requests a live DoorDash Drive delivery-fee quote for an order — the
  # storefront-facing half of this extension (called from
  # Spree::Calculator::Shipping::DoordashQuote during checkout, M3) and
  # again at order.completed if the original quote expired (M4).
  #
  # `order.total` at whichever moment this is called is what's sent as
  # order_value — Spree recalculates on every checkout step already, and
  # DoorDash isn't in the money path (Spree's own payment method still
  # charges the customer; DoorDash only uses this for delivery-fee/
  # insurance math).
  class Quote
    Result = Struct.new(:fee_cents, :currency, :external_delivery_id, :expires_at, keyword_init: true)

    def self.call(...) = new.call(...)

    def call(order)
      location_mapping = location_mapping_for(order)
      return nil unless location_mapping && order.ship_address

      client = SpreeDoordash::Client.for_store(order.store || Spree::Store.default)
      # A random suffix per attempt, not just order.number — confirmed live
      # against a real Sandbox quote: DoorDash rejects a *second*
      # /drive/v2/quotes call reusing the same external_delivery_id with a
      # 409 duplicate_delivery_id, even though the first quote is still open
      # (not yet accepted or expired). Checkout recalculates shipping rates
      # on essentially every step, so calling this twice for the same order
      # is the normal case, not an edge case — a stable per-order id made
      # the DoorDash rate silently vanish (RequestError is rescued below,
      # same as any other unserviceable-rate case) after the very first
      # quote. QuoteMapping upserts on order, so only the most recent
      # attempt's id is kept — the one that matters for accept (M4).
      external_delivery_id = "spree-doordash-#{order.number}-#{SecureRandom.hex(4)}"

      response = client.create_quote(build_payload(order, location_mapping, external_delivery_id))
      mapping = persist_quote!(order, external_delivery_id, response)

      Result.new(
        fee_cents: mapping.quoted_fee_cents,
        currency: mapping.currency,
        external_delivery_id: mapping.external_delivery_id,
        expires_at: mapping.quote_expires_at
      )
    rescue SpreeDoordash::Client::MissingCredentialsError, SpreeDoordash::RequestError => e
      # Unserviceable address, no credential connected, DoorDash-side
      # rejection — none of these should ever raise into checkout. The
      # calculator (M3) treats a nil Result as "this rate isn't available",
      # Spree's normal shape for "can't quote this," same as a carrier
      # simply not covering an address.
      Rails.logger.info("[SpreeDoordash] quote skipped for order #{order.number}: #{e.message}")
      nil
    end

    private

    def location_mapping_for(order)
      # Queried directly rather than `order.shipments.first` — creating a
      # shipment via `Spree::Shipment.create(order: order, ...)` (setting
      # the FK directly, as spec factories and some checkout code paths do)
      # doesn't invalidate an already-loaded `order` object's cached
      # `shipments` association the way `order.shipments.create(...)`
      # would. Querying fresh here means this is correct regardless of
      # what the caller already touched on `order`.
      stock_location = Spree::Shipment.where(order_id: order.id).first&.stock_location ||
                        Spree::StockLocation.find_by(default: true)
      return nil unless stock_location

      SpreeDoordash::LocationMapping.find_by(stock_location: stock_location)
    end

    def build_payload(order, location_mapping, external_delivery_id)
      {
        external_delivery_id: external_delivery_id,
        pickup_address: format_address(location_mapping.stock_location),
        pickup_business_name: location_mapping.stock_location.name,
        pickup_phone_number: location_mapping.stock_location.phone.presence || '+10000000000',
        pickup_instructions: location_mapping.stock_location.pickup_instructions,
        dropoff_address: format_address(order.ship_address),
        dropoff_phone_number: order.ship_address.phone.presence || '+10000000000',
        order_value: (order.total * 100).to_i
      }
    end

    # Spree::StockLocation and Spree::Address share the same field shape
    # (address1/address2/city/state/zipcode/country) even though they're
    # unrelated classes — DoorDash wants one flat string, not structured
    # fields.
    def format_address(record)
      [
        record.address1,
        record.address2,
        record.city,
        record.state&.abbr || record.state_name,
        record.zipcode,
        record.country&.iso_name
      ].compact_blank.join(', ')
    end

    def persist_quote!(order, external_delivery_id, response)
      mapping = SpreeDoordash::QuoteMapping.find_or_initialize_by(order: order)
      mapping.update!(
        external_delivery_id: external_delivery_id,
        quoted_fee_cents: response['fee'],
        currency: response['currency'] || 'USD',
        # DoorDash's own documented quote validity window.
        quote_expires_at: 5.minutes.from_now,
        pickup_time_estimated: parse_time(response['pickup_time_estimated']),
        dropoff_time_estimated: parse_time(response['dropoff_time_estimated']),
        raw_response: response
      )
      mapping
    end

    def parse_time(value)
      value.present? ? Time.iso8601(value) : nil
    end
  end
end
