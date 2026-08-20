RSpec.describe 'Spree::OrderDecorator', type: :model do
  # Deliberately does NOT stub Spree::Stock::Package/InventoryUnit the way
  # doordash_quote_spec.rb's unit tests do (instance_double(..., order:
  # order) makes package.order == order by construction, which is exactly
  # what hides this bug — see that spec file's comments). This spec goes
  # through the real order_routing_strategy -> Estimator -> Packer ->
  # InventoryUnitBuilder path, the only way to actually exercise the
  # object-identity boundary the fix bridges across. Only
  # SpreeDoordash::Quote.call is stubbed (avoids a real DoorDash API call);
  # everything else — the shipping method, the package, the order — is real.
  let(:order) { create(:order_with_line_items, line_items_count: 1) }

  before do
    shipping_category = order.line_items.first.variant.shipping_category
    create(
      :shipping_method,
      calculator: Spree::Calculator::Shipping::DoordashQuote.new,
      shipping_categories: [shipping_category],
      zones: [Spree::Zone.global]
    )
    # The factory's own shipment (built directly via create(:shipment,...),
    # bypassing create_proposed_shipments entirely) isn't what's under
    # test here — clear it so create_proposed_shipments below does the
    # real routing/estimation work from scratch.
    order.shipments.destroy_all
  end

  describe '#create_proposed_shipments' do
    it 'merges the doordash_quote_unavailable warning onto the real order when the quote fails' do
      allow(SpreeDoordash::Quote).to receive(:call).and_return(nil)

      order.create_proposed_shipments

      expect(order.warnings.map { |w| w[:code] }).to include('doordash_quote_unavailable')
    end

    it 'does not add a warning when the quote succeeds' do
      allow(SpreeDoordash::Quote).to receive(:call).and_return(
        SpreeDoordash::Quote::Result.new(fee_cents: 975, currency: 'USD', external_delivery_id: 'x', expires_at: Time.current)
      )

      order.create_proposed_shipments

      expect(order.warnings).to be_empty
    end

    it 'clears the thread-local flag after merging, so it does not leak into a later, unrelated recomputation' do
      allow(SpreeDoordash::Quote).to receive(:call).and_return(nil)

      order.create_proposed_shipments

      expect(Spree::Calculator::Shipping::DoordashQuote.unavailable?(order.id)).to be false
    end

    it 'clears a stale flag left behind by an earlier, incomplete call before doing anything else' do
      # Simulates a prior create_proposed_shipments call that set the flag
      # but never reached the merge step (e.g. raised partway through) —
      # the next call for this same order id must start clean rather than
      # attaching a leftover warning to a now-successful quote.
      Spree::Calculator::Shipping::DoordashQuote.mark_unavailable(order.id)
      allow(SpreeDoordash::Quote).to receive(:call).and_return(
        SpreeDoordash::Quote::Result.new(fee_cents: 975, currency: 'USD', external_delivery_id: 'x', expires_at: Time.current)
      )

      order.create_proposed_shipments

      expect(order.warnings).to be_empty
    end

    it 'does not add a warning for an order with no DoorDash shipping method at all' do
      # A distinct shipping_category (not the one the DoorDash method above
      # is attached to) plus its own variant — order_with_line_items alone
      # isn't enough isolation, since its variant defaults to
      # Spree::ShippingCategory.first, the exact category the DoorDash
      # method in the outer `before` block is attached to.
      other_category = create(:shipping_category, name: 'Unrelated category')
      other_product = create(:product, shipping_category: other_category)
      other_order = create(:order_with_line_items, variants: [other_product.master])
      allow(SpreeDoordash::Quote).to receive(:call).and_return(nil)

      other_order.create_proposed_shipments

      expect(other_order.warnings).to be_empty
    end
  end
end
