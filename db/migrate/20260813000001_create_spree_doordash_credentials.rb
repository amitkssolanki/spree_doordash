class CreateSpreeDoordashCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_doordash_credentials do |t|
      t.references :store, null: false, foreign_key: { to_table: :spree_stores }, index: { unique: true }

      # No OAuth/refresh flow — DoorDash Drive auth is a JWT signed
      # client-side per request from a static access key (developer_id +
      # key_id + signing_secret), created once in DoorDash's Developer
      # Portal. All three encrypted at the application layer (see
      # SpreeDoordash::Credential) even though developer_id/key_id aren't
      # secret on their own, for consistency with signing_secret (which is).
      t.text :developer_id
      t.text :key_id
      t.text :signing_secret

      # The static Authorization header value configured as this store's
      # webhook Basic Auth in DoorDash's dashboard — DoorDash echoes it back
      # on every webhook call; SpreeDoordash::WebhookVerifier compares
      # against this rather than an HMAC signature (DoorDash has no
      # signing scheme the way Square does).
      t.text :webhook_basic_auth_token

      t.string :doordash_environment, null: false, default: 'sandbox'

      t.timestamps
    end
  end
end
