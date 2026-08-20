RSpec.describe Spree::Calculator::Shipping::DoordashQuote do
  let(:calculator) { described_class.new }
  let(:order) { create(:order, ship_address: create(:address)) }
  let(:package) { instance_double(Spree::Stock::Package, order: order) }

  describe '.description' do
    it 'is a human-readable label distinct from a flat/configured rate' do
      expect(described_class.description).to eq('DoorDash Drive (live quote)')
    end
  end

  describe 'registration' do
    it 'is registered with Spree so it appears as a selectable shipping-method calculator' do
      expect(Rails.application.config.spree.calculators.shipping_methods).to include(described_class)
    end

    it 'is a real Spree::ShippingCalculator subclass — what Spree::ShippingMethod.calculators filters on' do
      expect(described_class < Spree::ShippingCalculator).to be true
    end
  end

  describe '#compute_package' do
    it 'returns the live quote fee, in dollars, when SpreeDoordash::Quote succeeds' do
      allow(SpreeDoordash::Quote).to receive(:call).with(order).and_return(
        SpreeDoordash::Quote::Result.new(fee_cents: 975, currency: 'USD', external_delivery_id: 'x', expires_at: Time.current)
      )

      expect(calculator.compute_package(package)).to eq(9.75)
    end

    it 'returns nil (no rate) when SpreeDoordash::Quote returns nil — unserviceable address, no credential, etc.' do
      allow(SpreeDoordash::Quote).to receive(:call).with(order).and_return(nil)

      expect(calculator.compute_package(package)).to be_nil
    end

    it 'pushes a doordash_quote_unavailable warning onto the order when the quote fails — a real bug found live, previously silent' do
      allow(SpreeDoordash::Quote).to receive(:call).with(order).and_return(nil)

      calculator.compute_package(package)

      expect(order.warnings.map { |w| w[:code] }).to include('doordash_quote_unavailable')
    end

    it 'does not push a warning when the quote succeeds' do
      allow(SpreeDoordash::Quote).to receive(:call).with(order).and_return(
        SpreeDoordash::Quote::Result.new(fee_cents: 975, currency: 'USD', external_delivery_id: 'x', expires_at: Time.current)
      )

      calculator.compute_package(package)

      expect(order.warnings).to be_empty
    end
  end

  describe '#available?' do
    it 'is true once the order has a ship address' do
      expect(calculator.available?(package)).to be true
    end

    it 'is false before the order has a ship address, without calling the DoorDash API at all' do
      expect(SpreeDoordash::Quote).not_to receive(:call)
      no_address_order = create(:order, ship_address: nil)
      package_without_address = instance_double(Spree::Stock::Package, order: no_address_order)

      expect(calculator.available?(package_without_address)).to be false
    end
  end
end
