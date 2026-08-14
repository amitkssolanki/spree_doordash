RSpec.describe SpreeDoordash::OrderCompletedSubscriber do
  describe 'registration' do
    # Spree::Subscriber's own docstring claims subscribers are
    # "automatically registered during Rails initialization" — that's not
    # what spree_core 5.6.1 actually does (Spree::Events.register_subscribers!
    # only ever iterates the explicit Spree.subscribers array). Every other
    # test in this file calls `described_class.call(event)` directly, which
    # would keep passing even if this class were never wired to the real
    # 'order.completed' event at all — confirmed live: a real storefront
    # order completed with DoorDash Delivery selected and was silently
    # never dispatched, because config/initializers/spree.rb didn't exist.
    it 'is registered with Spree so it actually receives real order.completed events' do
      expect(Spree.subscribers).to include(described_class)
    end
  end

  describe '.call' do
    it 'enqueues a DeliveryDispatchJob when the order was fulfilled via a DoorDash Delivery shipping method' do
      doordash_method = create(:shipping_method, calculator: Spree::Calculator::Shipping::DoordashQuote.new)
      order = create(:order)
      shipment = create(:shipment, order: order)
      rate = shipment.add_shipping_method(doordash_method, true)
      shipment.selected_shipping_rate_id = rate.id # deselects the factory's own default rate

      event = Spree::Event.new(name: 'order.completed', payload: { 'id' => order.to_param })

      expect(SpreeDoordash::DeliveryDispatchJob).to receive(:perform_later).with(order.id)

      described_class.call(event)
    end

    it 'is a safe no-op for an order fulfilled via a non-DoorDash shipping method' do
      order = create(:order)
      create(:shipment, order: order)

      event = Spree::Event.new(name: 'order.completed', payload: { 'id' => order.to_param })

      expect(SpreeDoordash::DeliveryDispatchJob).not_to receive(:perform_later)

      described_class.call(event)
    end

    it 'is a safe no-op when the payload id does not resolve to a real order' do
      event = Spree::Event.new(name: 'order.completed', payload: { 'id' => 'or_doesnotexist' })

      expect(SpreeDoordash::DeliveryDispatchJob).not_to receive(:perform_later)

      expect { described_class.call(event) }.not_to raise_error
    end
  end
end
