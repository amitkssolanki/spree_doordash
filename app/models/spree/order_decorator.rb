module Spree
  # Bridges Spree::Calculator::Shipping::DoordashQuote#compute_package's
  # doordash_quote_unavailable warning back onto the real order object.
  #
  # A real bug found live (confirmed via object_id tracing against
  # production, not assumed): `compute_package` receives a
  # `Spree::Stock::Package`, and `package.order` is NOT the same in-memory
  # object as `self` in `create_proposed_shipments` below. spree_core's own
  # `Spree::Stock::InventoryUnitBuilder#units` builds each inventory unit
  # with `order_id: @order.id` but deliberately *not* `order: @order` — its
  # own comment says why: "avoid loading the association to order until
  # needed." The first thing that touches `.order` on one of those units (or
  # a Package built from them) triggers a fresh `Spree::Order.find`, a
  # brand-new Ruby object. So `package.order.warnings |= [...]` inside the
  # calculator was mutating a throwaway copy that's discarded the instant
  # `compute_package` returns — the warning never reached the order object
  # this request actually serializes back to the storefront as
  # `cart.warnings`. `spree_doordash` v0.1.2's warning never worked in
  # production despite passing its own specs (the dummy app's specs call
  # the calculator directly against a single order instance, which can't
  # exhibit this — it only shows up through the real
  # create_proposed_shipments -> order_routing_strategy -> Estimator path).
  #
  # Fix: since Ruby object identity doesn't survive that boundary, bridge
  # across it with the order's stable id instead, via a thread-local flag
  # (see DoordashQuote.mark_unavailable/unavailable?/clear_unavailable for
  # why Thread.current was chosen over Rails.cache). Cleared unconditionally
  # at the *start* of every call — not just after a successful merge — so a
  # stale flag left behind by an earlier request that raised before
  # reaching the merge step can never leak into a later, unrelated
  # create_proposed_shipments call that happens to reuse the same thread.
  module OrderDecorator
    def create_proposed_shipments
      Spree::Calculator::Shipping::DoordashQuote.clear_unavailable(id)
      result = super
      merge_doordash_quote_warning!
      result
    end

    private

    def merge_doordash_quote_warning!
      return unless Spree::Calculator::Shipping::DoordashQuote.unavailable?(id)

      Spree::Calculator::Shipping::DoordashQuote.clear_unavailable(id)
      self.warnings |= [{
        code: 'doordash_quote_unavailable',
        message: 'We could not get a DoorDash delivery quote for this address.'
      }]
    end
  end

  Order.prepend OrderDecorator
end
