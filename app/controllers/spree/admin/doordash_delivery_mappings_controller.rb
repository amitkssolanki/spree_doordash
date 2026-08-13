module Spree
  module Admin
    # Read-only support/diagnostic view — no create/edit/destroy, this is
    # visibility into what spree_doordash has already dispatched, not a
    # place to change it. See config/routes.rb (only: [:index]).
    class DoordashDeliveryMappingsController < ResourceController
      def model_class
        SpreeDoordash::DeliveryMapping
      end
    end
  end
end
