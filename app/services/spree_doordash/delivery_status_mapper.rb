module SpreeDoordash
  # Applies a DoorDash delivery webhook event to the mapped Spree order —
  # the DoorDash analog of SpreeSquare::OrderStatusMapper.
  #
  # DoorDash's own event_name vocabulary (verified against
  # developer.doordash.com/en-US/docs/drive/reference/webhooks/, not
  # assumed): DASHER_CONFIRMED, DASHER_CONFIRMED_PICKUP_ARRIVAL,
  # DASHER_PICKED_UP, DASHER_CONFIRMED_DROPOFF_ARRIVAL, DASHER_DROPPED_OFF,
  # DELIVERY_CANCELLED, plus return-to-pickup-only events
  # (DELIVERY_RETURN_INITIALIZED, DASHER_CONFIRMED_RETURN_ARRIVAL,
  # DELIVERY_RETURNED) and DELIVERY_BATCHED for pre-staged batches.
  #
  # No version/sequence field exists in DoorDash's payload the way Square's
  # does, so — like OrderStatusMapper — this doesn't attempt to gate on
  # ordering. Safety against duplicate delivery instead comes entirely from
  # WebhookEvent's idempotency key (a genuine redelivery never reaches this
  # class a second time) and from the state-guarded, idempotent operations
  # below. DoorDash's own docs note events are sent "as soon as the event
  # takes place," in the natural lifecycle order, but that ordering
  # guarantee (or lack of one) across concurrent webhook workers is
  # unverified until seen live — flagged here rather than assumed, same
  # precedent as OrderStatusMapper's own comment.
  class DeliveryStatusMapper
    SHIP_EVENTS = %w[DASHER_DROPPED_OFF].freeze
    CANCEL_EVENTS = %w[DELIVERY_CANCELLED].freeze
    # Real, DoorDash-lifecycle events with no Spree shipment_state
    # equivalent — recorded as a friendly last_status label only, same
    # "label vs. state transition" split as OrderStatusMapper's
    # FULFILLMENT_LABEL_STATES. DELIVERY_RETURNED (the order came back to
    # the store, never reached the customer) arguably deserves the same
    # treatment as a cancellation, but is left label-only until this
    # extension has actually observed one live — not assumed.
    LABEL_ONLY_EVENTS = %w[
      DASHER_CONFIRMED DASHER_CONFIRMED_PICKUP_ARRIVAL DASHER_CONFIRMED_DROPOFF_ARRIVAL
      DELIVERY_RETURN_INITIALIZED DASHER_CONFIRMED_RETURN_ARRIVAL DELIVERY_RETURNED DELIVERY_BATCHED
    ].freeze

    def self.call(...) = new.call(...)

    def call(payload)
      mapping = SpreeDoordash::DeliveryMapping.find_by(external_delivery_id: payload['external_delivery_id'])
      return unless mapping

      event_name = payload['event_name']
      order = mapping.order

      case event_name
      when *SHIP_EVENTS
        ship!(order)
      when *CANCEL_EVENTS
        cancel!(order)
      when *LABEL_ONLY_EVENTS
        # No Spree-side transition — last_status below is the only effect.
      end

      mapping.update!(
        last_status: event_name || mapping.last_status,
        tracking_url: payload['tracking_url'].presence || mapping.tracking_url,
        dasher_name: payload['dasher_name'].presence || mapping.dasher_name,
        dasher_phone: payload['dasher_dropoff_phone_number'].presence || mapping.dasher_phone
      )
    end

    private

    def ship!(order)
      order.shipments.each { |shipment| shipment.ship! if shipment.ready? }
    end

    def cancel!(order)
      order.cancel! unless order.canceled?
    end
  end
end
