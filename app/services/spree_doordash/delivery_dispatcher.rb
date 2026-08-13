module SpreeDoordash
  # Dispatches a completed order to DoorDash: accepts its already-open
  # quote if one exists and hasn't expired, or requests a fresh quote and
  # accepts that instead. Quotes are only valid 5 minutes (DoorDash's own
  # limit) — checkout can easily take longer, so by the time an order
  # actually completes the quote generated during checkout (M3) may already
  # be stale.
  class DeliveryDispatcher
    def self.call(...) = new.call(...)

    def call(order)
      quote_mapping = quote_mapping_for(order)
      return nil unless quote_mapping

      client = SpreeDoordash::Client.for_store(order.store || Spree::Store.default)
      response = client.accept_quote(quote_mapping.external_delivery_id)

      persist_delivery!(order, quote_mapping.external_delivery_id, response)
    rescue SpreeDoordash::Client::MissingCredentialsError, SpreeDoordash::RequestError => e
      Rails.logger.error("[SpreeDoordash] dispatch failed for order #{order.number}: #{e.message}")
      SpreeDoordash::DeliveryMapping.find_or_initialize_by(order: order).mark_failed!(e)
      SpreeDoordash::Alerting.capture(e, context: { area: 'dispatch', order_number: order.number })
      nil
    end

    private

    # A fresh quote (not the order's existing one, if any) — same rationale
    # as SpreeDoordash::Quote's own external_delivery_id comment: reusing an
    # id DoorDash has already seen gets rejected. Requesting via the same
    # Quote service keeps this in one place rather than duplicating
    # quote-building here.
    def quote_mapping_for(order)
      existing = SpreeDoordash::QuoteMapping.find_by(order: order)
      return existing if existing && !existing.expired?

      SpreeDoordash::Quote.call(order)
      SpreeDoordash::QuoteMapping.find_by(order: order)
    end

    def persist_delivery!(order, external_delivery_id, response)
      mapping = SpreeDoordash::DeliveryMapping.find_or_initialize_by(order: order)
      mapping.update!(
        external_delivery_id: external_delivery_id,
        last_status: response['delivery_status'],
        tracking_url: response['tracking_url'],
        dasher_name: response['dasher_name'],
        dasher_phone: response['dasher_dropoff_phone_number'],
        raw_response: response
      )
      mapping
    end
  end
end
