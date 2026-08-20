require_dependency 'spree/shipping_calculator'

module Spree
  # Compact `module Calculator::Shipping` (not separately-nested `module
  # Calculator; module Shipping`) — Spree::Calculator is already a class,
  # not a module, in spree_core; nesting it that way raises `TypeError:
  # Calculator is not a module`. This is the exact form spree_core's own
  # calculators (e.g. Spree::Calculator::Shipping::FlatRate) use.
  module Calculator::Shipping
    # Prices a "DoorDash Delivery" shipping method against a real, live
    # DoorDash Drive quote rather than a flat/configured rate.
    # Spree::Stock::Estimator calls `calculator.compute(package)`, which
    # Spree::Calculator#compute dispatches to `compute_package` by
    # demodulizing the argument's class name (Spree::Stock::Package ->
    # "package") — no override of #compute itself needed.
    class DoordashQuote < ShippingCalculator
      def self.description
        'DoorDash Drive (live quote)'
      end

      def compute_package(package)
        result = SpreeDoordash::Quote.call(package.order)
        if result.nil?
          # A real bug found live: a nil Result here (bad/missing phone, an
          # address DoorDash genuinely can't serve, DoorDash API down —
          # SpreeDoordash::Quote#call collapses all of these to the same
          # "unavailable" nil, deliberately, so this stays generic to *why*)
          # used to just make the rate silently vanish with zero signal
          # anywhere in the UI. Spree::Order#warnings is the same
          # transient, request-scoped mechanism core's own
          # `ensure_available_shipping_rates` already uses for the
          # identical class of problem (a line item that can't ship at
          # all) — it flows through to the Store API's `cart.warnings`
          # with no new API surface needed. The storefront renders its own
          # localized copy for this code; `message` here is English-only,
          # a fallback for any other API consumer, not the UI text itself.
          package.order.warnings |= [{
            code: 'doordash_quote_unavailable',
            message: 'We could not get a DoorDash delivery quote for this address.'
          }]
          return nil
        end

        result.fee_cents / 100.0
      end

      # Called by Estimator to filter which shipping methods even attempt
      # a compute_package call. Skips the DoorDash API round-trip entirely
      # for an order with no ship address yet (early checkout, before
      # Estimator would sensibly be asked at all) — the real "can DoorDash
      # serve this address" check still happens inside SpreeDoordash::Quote
      # itself (compute_package returning nil is what actually makes the
      # rate not show up).
      def available?(package)
        package.order.ship_address.present?
      end
    end
  end
end
