RSpec.describe SpreeDoordash::Quote do
  let(:store) { create(:store) }
  let(:stock_location) { create(:stock_location, name: 'Downtown Branch', phone: '+14155550100') }
  let!(:location_mapping) { create(:doordash_location_mapping, stock_location: stock_location, store: store, doordash_store_id: 'sq_store_1') }
  let!(:credential) { create(:doordash_credential, store: store) }
  let(:order) do
    create(:order, store: store, ship_address: create(:address, phone: '+14155550199'))
  end
  let!(:shipment) { create(:shipment, order: order, stock_location: stock_location) }

  def stub_quote(fee: 599, status: 200)
    stub_request(:post, 'https://openapi.doordash.com/drive/v2/quotes')
      .to_return(status: status, body: { fee: fee, currency: 'USD', delivery_status: 'quote' }.to_json,
                 headers: { 'Content-Type' => 'application/json' })
  end

  describe '.call' do
    it 'requests a quote and persists it on a QuoteMapping' do
      stub_quote(fee: 975)

      result = described_class.call(order)

      expect(result.fee_cents).to eq(975)
      expect(result.currency).to eq('USD')
      # Not an exact "spree-doordash-#{order.number}" match — a random
      # per-attempt suffix is appended (see Quote#call's comment: a stable
      # per-order id gets rejected by a real second /drive/v2/quotes call
      # for the same order with 409 duplicate_delivery_id).
      expect(result.external_delivery_id).to match(/\Aspree-doordash-#{order.number}-[0-9a-f]{8}\z/)

      mapping = SpreeDoordash::QuoteMapping.find_by(order: order)
      expect(mapping.quoted_fee_cents).to eq(975)
      expect(mapping.expired?).to be false
    end

    it 'sends the fulfilling stock location as pickup and the order ship_address as dropoff' do
      stub = stub_request(:post, 'https://openapi.doordash.com/drive/v2/quotes')
             .with { |req|
               body = JSON.parse(req.body)
               expect(body['pickup_business_name']).to eq('Downtown Branch')
               expect(body['pickup_address']).to include(stock_location.city)
               expect(body['dropoff_address']).to include(order.ship_address.city)
               true
             }
             .to_return(status: 200, body: { fee: 599, currency: 'USD' }.to_json, headers: { 'Content-Type' => 'application/json' })

      described_class.call(order)

      expect(stub).to have_been_requested
    end

    it 'upserts the same QuoteMapping row on a re-quote for the same order (not a second row)' do
      stub_quote(fee: 599)
      described_class.call(order)
      stub_quote(fee: 650)
      described_class.call(order)

      expect(SpreeDoordash::QuoteMapping.where(order: order).count).to eq(1)
      expect(SpreeDoordash::QuoteMapping.find_by(order: order).quoted_fee_cents).to eq(650)
    end

    it 'returns nil (does not raise) when no location mapping exists for the fulfilling stock location' do
      location_mapping.destroy!
      expect(described_class.call(order)).to be_nil
    end

    it 'returns nil (does not raise) when the store has no DoorDash credential connected' do
      credential.destroy!
      expect(described_class.call(order)).to be_nil
    end

    it 'returns nil (does not raise) when DoorDash rejects the address as unserviceable' do
      stub_quote(fee: nil, status: 400)
      expect(described_class.call(order)).to be_nil
    end
  end
end
