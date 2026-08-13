module SpreeDoordash
  # Events & Subscribers is the preferred pattern for this kind of side
  # effect (per this app's own CLAUDE.md conventions) — react to
  # order.completed without touching Spree::Order itself. Mirrors
  # SpreeSquare::OrderCompletedSubscriber's shape exactly; independent of
  # it — spree_square's own order push (kitchen ticket) still fires for
  # every order regardless of fulfillment method, DoorDash only decides who
  # carries it out the door.
  class OrderCompletedSubscriber < Spree::Subscriber
    subscribes_to 'order.completed'

    def handle(event)
      order = Spree::Order.find_by_prefix_id(event.payload['id'])
      return unless order
      return unless doordash_delivery?(order)

      SpreeDoordash::DeliveryDispatchJob.perform_later(order.id)
    end

    private

    # Only dispatch orders actually fulfilled via a "DoorDash Delivery"
    # shipping method — pickup/other-carrier orders should never reach
    # DoorDash at all.
    def doordash_delivery?(order)
      order.shipments.any? { |shipment| shipment.shipping_method&.calculator.is_a?(Spree::Calculator::Shipping::DoordashQuote) }
    end
  end
end
