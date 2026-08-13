RSpec.describe SpreeDoordash::DeliveryStatusMapper do
  let(:order) { create(:order, state: 'complete', completed_at: Time.current) }
  let!(:shipment) { create(:shipment, order: order, state: 'ready') }
  let(:mapping) { create(:doordash_delivery_mapping, order: order, external_delivery_id: 'del_123') }

  def payload(event_name, extra = {})
    { 'external_delivery_id' => mapping.external_delivery_id, 'event_name' => event_name }.merge(extra)
  end

  describe '.call' do
    it 'is a safe no-op when no DeliveryMapping matches the external_delivery_id' do
      expect { described_class.call({ 'external_delivery_id' => 'unknown', 'event_name' => 'DASHER_CONFIRMED' }) }
        .not_to raise_error
    end

    it 'ships every ready shipment on DASHER_DROPPED_OFF' do
      described_class.call(payload('DASHER_DROPPED_OFF'))

      expect(shipment.reload.state).to eq('shipped')
    end

    it 'cancels the order on DELIVERY_CANCELLED' do
      described_class.call(payload('DELIVERY_CANCELLED'))

      expect(order.reload.state).to eq('canceled')
    end

    it 'does not cancel an already-canceled order again' do
      order.cancel!
      expect(order).to receive(:cancel!).never

      described_class.call(payload('DELIVERY_CANCELLED'))
    end

    %w[DASHER_CONFIRMED DASHER_CONFIRMED_PICKUP_ARRIVAL DASHER_CONFIRMED_DROPOFF_ARRIVAL].each do |event_name|
      it "does not transition shipment or order state on #{event_name} (label-only)" do
        described_class.call(payload(event_name))

        expect(shipment.reload.state).not_to eq('shipped')
        expect(order.reload.state).not_to eq('canceled')
      end
    end

    it 'always records last_status, tracking_url, and dasher details from the payload' do
      described_class.call(payload('DASHER_CONFIRMED', {
                                     'tracking_url' => 'https://doordash.com/tracking?id=xyz',
                                     'dasher_name' => 'Jamie D.',
                                     'dasher_dropoff_phone_number' => '+15551234567'
                                   }))

      mapping.reload
      expect(mapping.last_status).to eq('DASHER_CONFIRMED')
      expect(mapping.tracking_url).to eq('https://doordash.com/tracking?id=xyz')
      expect(mapping.dasher_name).to eq('Jamie D.')
      expect(mapping.dasher_phone).to eq('+15551234567')
    end

    it 'keeps the previous tracking_url/dasher fields when a later event omits them (DoorDash only sends fields that are available)' do
      mapping.update!(tracking_url: 'https://doordash.com/tracking?id=xyz', dasher_name: 'Jamie D.')

      described_class.call(payload('DASHER_PICKED_UP'))

      mapping.reload
      expect(mapping.tracking_url).to eq('https://doordash.com/tracking?id=xyz')
      expect(mapping.dasher_name).to eq('Jamie D.')
    end
  end
end
