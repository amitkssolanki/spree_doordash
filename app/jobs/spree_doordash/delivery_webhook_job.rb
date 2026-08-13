module SpreeDoordash
  # Applies one already-verified, already-deduplicated DoorDash webhook
  # event to the order it's mapped to. Same retry/dead-letter/Alerting
  # shape as every other webhook-handling job in this codebase.
  class DeliveryWebhookJob < BaseJob
    retry_on StandardError, wait: :polynomially_longer, attempts: 5 do |job, error|
      SpreeDoordash::WebhookEvent.find_by(id: job.arguments.first)&.mark_failed!(error)
      SpreeDoordash::Alerting.capture(error, context: 'delivery_webhook')
    end

    def perform(webhook_event_id)
      event = SpreeDoordash::WebhookEvent.find(webhook_event_id)
      SpreeDoordash::DeliveryStatusMapper.call(event.payload)
      event.mark_processed!
    end
  end
end
