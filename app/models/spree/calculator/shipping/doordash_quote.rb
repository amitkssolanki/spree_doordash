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
          #
          # A SECOND real bug found live (v0.1.2, this fix is v0.1.3):
          # package.order is not the same object as the order the caller
          # holds (spree_core's InventoryUnitBuilder deliberately defers
          # loading that association — see the Spree::OrderDecorator this
          # gem ships for the full story), so pushing the warning directly
          # onto package.order.warnings here mutated a throwaway copy that
          # never reached the real order. Thread.current bridges across
          # that boundary via the order's id instead of Ruby object
          # identity — chosen over Rails.cache deliberately: this gem
          # installs into arbitrary host apps, some of which run
          # `config.cache_store = :null_store` (the Rails test-env
          # default, and a legitimate production choice too), which would
          # silently degrade this back to the original bug with no
          # indication anything was wrong. compute_package and
          # create_proposed_shipments always run synchronously on the same
          # thread within one request (confirmed: this is the exact call
          # chain reproduced live to root-cause the original bug), so a
          # thread-local flag needs no external store and no expiry logic
          # — Spree::OrderDecorator clears it unconditionally at the start
          # of every create_proposed_shipments call, so a stale flag from
          # an earlier request that errored out before consuming it can
          # never leak into a later, unrelated one.
          self.class.mark_unavailable(package.order.id)
          return nil
        end

        result.fee_cents / 100.0
      end

      def self.mark_unavailable(order_id)
        (Thread.current[:spree_doordash_quote_unavailable_order_ids] ||= []) << order_id
      end

      def self.unavailable?(order_id)
        Thread.current[:spree_doordash_quote_unavailable_order_ids]&.include?(order_id) || false
      end

      def self.clear_unavailable(order_id)
        Thread.current[:spree_doordash_quote_unavailable_order_ids]&.delete(order_id)
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
