module Spree
  module Admin
    # Read-only support/diagnostic view of every inbound DoorDash webhook —
    # what arrived, whether it processed, and the error if it didn't.
    class DoordashWebhookEventsController < ResourceController
      def model_class
        SpreeDoordash::WebhookEvent
      end
    end
  end
end
