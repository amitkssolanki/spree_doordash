module SpreeDoordash
  # Idempotency + audit log for inbound DoorDash webhook notifications.
  #
  # Unlike SpreeSquare::WebhookEvent, there's no single event_id in the
  # payload to key off — the unique index instead covers
  # (external_delivery_id, event_name, payload_digest), see the migration
  # for why each piece is needed. That's what makes DoorDash's documented
  # up-to-3x redelivery-on-non-200 safe to process without duplicating side
  # effects.
  class WebhookEvent < Spree.base_class
    self.table_name = 'spree_doordash_webhook_events'

    validates :external_delivery_id, presence: true
    validates :event_name, presence: true
    validates :payload_digest, presence: true, uniqueness: { scope: %i[external_delivery_id event_name] }

    scope :pending, -> { where(status: 'pending') }

    def self.digest(raw_body)
      Digest::SHA256.hexdigest(raw_body)
    end

    def mark_processed!
      update!(status: 'processed', processed_at: Time.current)
    end

    def mark_failed!(error)
      update!(status: 'failed', processed_at: Time.current, error_message: error.to_s.truncate(1000))
    end
  end
end
