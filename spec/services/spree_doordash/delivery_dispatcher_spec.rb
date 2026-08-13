RSpec.describe SpreeDoordash::DeliveryDispatcher do
  let(:store) { create(:store) }
  let(:stock_location) { create(:stock_location, name: 'Downtown Branch', phone: '+14155550100') }
  let!(:location_mapping) { create(:doordash_location_mapping, stock_location: stock_location, store: store, doordash_store_id: 'sq_store_1') }
  let!(:credential) { create(:doordash_credential, store: store) }
  let(:order) { create(:order, store: store, ship_address: create(:address, phone: '+14155550199')) }
  let!(:shipment) { create(:shipment, order: order, stock_location: stock_location) }

  def stub_quote(fee: 599, status: 200)
    stub_request(:post, 'https://openapi.doordash.com/drive/v2/quotes')
      .to_return(status: status, body: { fee: fee, currency: 'USD', delivery_status: 'quote' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  def stub_accept(external_delivery_id, status: 200)
    stub_request(:post, "https://openapi.doordash.com/drive/v2/quotes/#{external_delivery_id}/accept")
      .to_return(status: status, body: {
        delivery_status: 'created', tracking_url: 'https://doordash.com/tracking?id=abc',
        dasher_name: nil, external_delivery_id: external_delivery_id
      }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  describe '.call' do
    it 'accepts an existing, unexpired quote directly (no re-quote)' do
      existing = create(:doordash_quote_mapping, order: order, external_delivery_id: 'existing-quote-id', quote_expires_at: 4.minutes.from_now)
      accept_stub = stub_accept('existing-quote-id')

      result = described_class.call(order)

      expect(accept_stub).to have_been_requested
      expect(result.external_delivery_id).to eq('existing-quote-id')
      expect(SpreeDoordash::DeliveryMapping.find_by(order: order)).to be_present
      expect(existing.reload.external_delivery_id).to eq('existing-quote-id') # untouched
    end

    it 're-quotes first when there is no existing quote, then accepts the fresh one' do
      quote_stub = stub_quote(fee: 975)
      # We don't know the random external_delivery_id ahead of time, so stub
      # the accept endpoint for any id under this order's prefix.
      accept_stub = stub_request(:post, %r{https://openapi\.doordash\.com/drive/v2/quotes/spree-doordash-#{order.number}-[0-9a-f]{8}/accept})
                    .to_return(status: 200, body: { delivery_status: 'created', tracking_url: 'https://doordash.com/tracking?id=abc' }.to_json,
                               headers: { 'Content-Type' => 'application/json' })

      result = described_class.call(order)

      expect(quote_stub).to have_been_requested
      expect(accept_stub).to have_been_requested
      expect(result.last_status).to eq('created')
    end

    it 're-quotes when the existing quote has expired' do
      create(:doordash_quote_mapping, order: order, external_delivery_id: 'stale-quote-id', quote_expires_at: 1.minute.ago)
      quote_stub = stub_quote(fee: 650)
      accept_stub = stub_request(:post, %r{https://openapi\.doordash\.com/drive/v2/quotes/spree-doordash-#{order.number}-[0-9a-f]{8}/accept})
                    .to_return(status: 200, body: { delivery_status: 'created' }.to_json, headers: { 'Content-Type' => 'application/json' })

      described_class.call(order)

      expect(quote_stub).to have_been_requested
      expect(accept_stub).to have_been_requested
    end

    it 'returns nil and records the failure when accept is rejected (e.g. quote expired on DoorDash'"'"'s side)' do
      create(:doordash_quote_mapping, order: order, external_delivery_id: 'expired-on-doordash', quote_expires_at: 4.minutes.from_now)
      stub_request(:post, 'https://openapi.doordash.com/drive/v2/quotes/expired-on-doordash/accept')
        .to_return(status: 422, body: { code: 'quote_expired' }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = described_class.call(order)

      expect(result).to be_nil
      mapping = SpreeDoordash::DeliveryMapping.find_by(order: order)
      expect(mapping.dispatch_error).to be_present
    end

    it 'returns nil (does not raise) when there is no quote and no location mapping to build one from' do
      location_mapping.destroy!

      result = described_class.call(order)

      expect(result).to be_nil
    end
  end
end
