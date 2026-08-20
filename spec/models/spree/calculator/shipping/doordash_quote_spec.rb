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

    after do
      # mark_unavailable's Thread.current flag is only ever meant to live
      # for the span of one create_proposed_shipments call — clean up
      # between examples so a failed assertion here can't bleed into
      # a later one on the same test-runner thread.
      described_class.clear_unavailable(order.id)
    end

    it 'marks the order id unavailable (thread-local) when the quote fails' do
      # NOT order.warnings directly — see Spree::OrderDecorator for why.
      # package.order (an instance_double here, deliberately == order) hides
      # the real bug this design works around: in production, package.order
      # is a freshly-queried, separate Spree::Order object from the one
      # create_proposed_shipments holds (spree_core's InventoryUnitBuilder
      # defers loading that association on purpose), so a direct
      # `package.order.warnings |= [...]` here would mutate a throwaway
      # copy — confirmed live via object_id tracing against production, not
      # assumed. The thread-local flag, keyed by the order's stable id
      # rather than Ruby object identity, is what actually survives that
      # boundary; see order_decorator_spec.rb for the real, non-doubled
      # integration test.
      allow(SpreeDoordash::Quote).to receive(:call).with(order).and_return(nil)

      calculator.compute_package(package)

      expect(described_class.unavailable?(order.id)).to be true
    end

    it 'does not mark the order unavailable when the quote succeeds' do
      allow(SpreeDoordash::Quote).to receive(:call).with(order).and_return(
        SpreeDoordash::Quote::Result.new(fee_cents: 975, currency: 'USD', external_delivery_id: 'x', expires_at: Time.current)
      )

      calculator.compute_package(package)

      expect(described_class.unavailable?(order.id)).to be false
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
