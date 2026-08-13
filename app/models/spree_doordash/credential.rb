module SpreeDoordash
  # A DoorDash Drive access key + webhook secret for one Spree::Store.
  # Unlike SpreeSquare::Credential, this isn't an OAuth connection — DoorDash
  # Drive auth is a static access key (developer_id/key_id/signing_secret),
  # created once in DoorDash's Developer Portal and entered directly here,
  # used to sign a fresh short-lived JWT per API call (see
  # SpreeDoordash::Client). No refresh flow, so no expires_at/needs_refresh?
  # the way Square's Credential has.
  class Credential < Spree.base_class
    self.table_name = 'spree_doordash_credentials'

    belongs_to :store, class_name: 'Spree::Store'

    encrypts :developer_id, :key_id, :signing_secret, :webhook_basic_auth_token

    validates :store, presence: true, uniqueness: true
    validates :developer_id, :key_id, :signing_secret, presence: true

    def sandbox?
      doordash_environment == 'sandbox'
    end
  end
end
