module SpreeDoordash
  # Maps a Spree::Order to the DoorDash delivery it was dispatched to on
  # acceptance — the DoorDash analog of SpreeSquare::OrderMapping.
  # external_delivery_id is the accepted quote's id, reused as the
  # delivery's own id for its whole lifecycle (DoorDash issues no separate
  # delivery id).
  class DeliveryMapping < Spree.base_class
    self.table_name = 'spree_doordash_delivery_mappings'

    belongs_to :order, class_name: 'Spree::Order'

    validates :order, presence: true, uniqueness: true
    # No presence requirement — mirrors SpreeSquare::OrderMapping's own
    # square_order_id: DeliveryDispatchJob's dead-letter block does
    # `find_or_initialize_by(order:).mark_failed!(error)` on a dispatch that
    # can fail before a delivery (and therefore an external_delivery_id)
    # ever exists — e.g. no LocationMapping, or the underlying quote itself
    # failed. allow_nil so two such failed-before-dispatch rows don't
    # collide on the uniqueness check (nil is a valid, repeatable "no
    # delivery yet" state, not itself a real id).
    validates :external_delivery_id, uniqueness: true, allow_nil: true

    def mark_failed!(error)
      update!(dispatch_error: error.to_s.truncate(2000))
    end
  end
end
