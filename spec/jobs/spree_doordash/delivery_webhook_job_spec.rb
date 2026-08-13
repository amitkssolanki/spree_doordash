RSpec.describe SpreeDoordash::DeliveryWebhookJob do
  describe '#perform' do
    it "maps the event's payload and marks the webhook event processed" do
      event = create(:doordash_webhook_event, external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED',
                                                payload: { 'external_delivery_id' => 'del_1', 'event_name' => 'DASHER_CONFIRMED' })

      expect(SpreeDoordash::DeliveryStatusMapper).to receive(:call).with(event.payload)

      described_class.perform_now(event.id)

      expect(event.reload.status).to eq('processed')
    end
  end

  describe 'when retries are exhausted' do
    it 'marks the webhook event failed and alerts, and does not let the error escape' do
      event = create(:doordash_webhook_event)
      allow(SpreeDoordash::DeliveryStatusMapper).to receive(:call).and_raise(StandardError, 'boom')
      expect(SpreeDoordash::Alerting).to receive(:capture).with(instance_of(StandardError), context: 'delivery_webhook')

      job = described_class.new(event.id)
      job.exception_executions = { '[StandardError]' => 4 }

      expect { job.perform_now }.not_to raise_error

      expect(event.reload.status).to eq('failed')
    end
  end
end
