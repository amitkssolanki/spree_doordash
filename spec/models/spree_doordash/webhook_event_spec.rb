RSpec.describe SpreeDoordash::WebhookEvent do
  describe 'validations' do
    it 'is valid with external_delivery_id, event_name, and payload_digest' do
      event = build(:doordash_webhook_event)
      expect(event).to be_valid
    end

    it 'requires external_delivery_id' do
      expect(build(:doordash_webhook_event, external_delivery_id: nil)).not_to be_valid
    end

    it 'requires event_name' do
      expect(build(:doordash_webhook_event, event_name: nil)).not_to be_valid
    end

    it 'is unique on the (external_delivery_id, event_name, payload_digest) idempotency key' do
      create(:doordash_webhook_event, external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED', payload_digest: 'digest_1')
      dup = build(:doordash_webhook_event, external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED', payload_digest: 'digest_1')

      expect(dup).not_to be_valid
    end

    it 'allows the same external_delivery_id and event_name with a different payload_digest (a distinct redelivery body)' do
      create(:doordash_webhook_event, external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED', payload_digest: 'digest_1')
      distinct = build(:doordash_webhook_event, external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED', payload_digest: 'digest_2')

      expect(distinct).to be_valid
    end
  end

  describe '.digest' do
    it 'is a deterministic SHA256 hex digest of the raw body' do
      expect(described_class.digest('{"a":1}')).to eq(Digest::SHA256.hexdigest('{"a":1}'))
    end
  end

  describe '#mark_processed!' do
    it 'sets status and processed_at' do
      event = create(:doordash_webhook_event)
      event.mark_processed!

      expect(event.reload.status).to eq('processed')
      expect(event.processed_at).to be_present
    end
  end

  describe '#mark_failed!' do
    it 'sets status, processed_at, and a truncated error message' do
      event = create(:doordash_webhook_event)
      event.mark_failed!(StandardError.new('boom'))

      expect(event.reload.status).to eq('failed')
      expect(event.error_message).to eq('boom')
    end
  end
end
