module SpreeDoordash
  # A failed dispatch is the worst failure mode in this whole extension —
  # payment already taken, kitchen already has the ticket (spree_square's
  # own push is independent), but no one is actually coming to pick it up.
  # Same retry/dead-letter/Alerting shape as SpreeSquare::OrderPushJob for
  # exactly that reason.
  class DeliveryDispatchJob < BaseJob
    retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
      order = Spree::Order.find_by(id: job.arguments.first)
      SpreeDoordash::DeliveryMapping.find_or_initialize_by(order: order).mark_failed!(error) if order
      SpreeDoordash::Alerting.capture(
        error,
        context: { area: 'delivery_dispatch', order_number: order&.number }
      )
    end

    def perform(order_id)
      order = Spree::Order.find(order_id)
      SpreeDoordash::DeliveryDispatcher.call(order)
    end
  end
end
