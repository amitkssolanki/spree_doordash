class CreateSpreeDoordashQuoteMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_doordash_quote_mappings do |t|
      t.references :order, null: false, foreign_key: { to_table: :spree_orders }, index: { unique: true }

      # Ours — "spree-doordash-#{order.number}-#{random suffix}" (see
      # SpreeDoordash::Quote; the random suffix is required — DoorDash
      # rejects a second /drive/v2/quotes call reusing the same id with 409
      # duplicate_delivery_id, confirmed against a real Sandbox re-quote).
      # The join key DoorDash's own webhooks and the accept-quote/
      # get-delivery calls all key off, same role as square_order_id plays
      # for spree_square's OrderMapping.
      t.string :external_delivery_id, null: false

      t.integer :quoted_fee_cents
      t.string :currency, default: 'USD'

      # A quote is only valid 5 minutes (DoorDash's own limit) — checked by
      # SpreeDoordash::DeliveryDispatcher (M4) to decide whether to accept
      # this quote as-is or re-quote fresh before accepting.
      t.datetime :quote_expires_at

      t.datetime :pickup_time_estimated
      t.datetime :dropoff_time_estimated

      # Full response, for debugging/support visibility — same rationale as
      # WebhookEvent#payload elsewhere in this codebase.
      t.json :raw_response

      t.timestamps
    end

    add_index :spree_doordash_quote_mappings, :external_delivery_id, unique: true
  end
end
