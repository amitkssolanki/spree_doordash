class CreateSpreeDoordashDeliveryMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_doordash_delivery_mappings do |t|
      t.references :order, null: false, foreign_key: { to_table: :spree_orders }, index: { unique: true }

      # The external_delivery_id of the quote that was accepted — becomes
      # the real delivery's own id once accept succeeds (DoorDash doesn't
      # issue a separate "delivery id"; the quote's external_delivery_id is
      # reused for the whole lifecycle, confirmed via
      # POST /drive/v2/quotes/{external_delivery_id}/accept in DoorDash's
      # own docs).
      # Nullable, unlike QuoteMapping's own external_delivery_id — a
      # DeliveryMapping row can legitimately exist before one is known (see
      # DeliveryDispatchJob's dead-letter block: a dispatch can fail before
      # ever reaching DoorDash's accept endpoint, e.g. no LocationMapping,
      # matching SpreeSquare::OrderMapping#square_order_id's own nullable
      # precedent for the same reason).
      t.string :external_delivery_id

      # DoorDash's own event_name vocabulary (DASHER_CONFIRMED,
      # DASHER_PICKED_UP, DASHER_DROPPED_OFF, DELIVERY_CANCELLED, ...) —
      # stored verbatim rather than mapped to a smaller enum, same
      # last_status rationale as SpreeSquare::OrderMapping.
      t.string :last_status

      t.string :tracking_url
      t.string :dasher_name
      t.string :dasher_phone
      t.text :dispatch_error

      # Full response from the accept call, for debugging/support
      # visibility — same rationale as QuoteMapping#raw_response.
      t.json :raw_response

      t.timestamps
    end

    add_index :spree_doordash_delivery_mappings, :external_delivery_id, unique: true
  end
end
