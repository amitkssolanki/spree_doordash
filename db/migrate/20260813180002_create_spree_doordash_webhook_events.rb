class CreateSpreeDoordashWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_doordash_webhook_events do |t|
      # DoorDash's webhook payloads carry no single event id of their own
      # (unlike Square's payload['event_id']) — DoorDash "sends each webhook
      # event up to 3 times" on anything other than a 200 (its own docs),
      # so the same body can arrive more than once. The idempotency key is
      # built from what IS in the payload: external_delivery_id + event_name
      # (which event this is) + a digest of the raw body (guards against two
      # genuinely different payloads that happened to share those two
      # fields, e.g. a future field DoorDash adds that changes between
      # otherwise-identical redeliveries).
      t.string :external_delivery_id, null: false
      t.string :event_name, null: false
      t.string :payload_digest, null: false

      # json, not jsonb — see CreateSpreeDoordashQuoteMappings for why
      # (SQLite dummy app, no SQL-level JSON querying here).
      t.json :payload, null: false, default: {}
      t.datetime :processed_at
      t.string :status, null: false, default: 'pending' # pending, processed, failed
      t.text :error_message

      t.timestamps
    end

    add_index :spree_doordash_webhook_events, %i[external_delivery_id event_name payload_digest],
              unique: true, name: 'index_spree_doordash_webhook_events_on_idempotency_key'
    add_index :spree_doordash_webhook_events, :event_name
  end
end
