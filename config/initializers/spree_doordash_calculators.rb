# Spree::ShippingMethod.calculators reads from a hardcoded list
# (Rails.application.config.spree.calculators.shipping_methods) that
# spree_core itself populates via its own `config.after_initialize` block
# (lib/spree/core/engine.rb) — NOT auto-discovery, despite
# Spree::ShippingCalculator subclasses otherwise looking like a
# convention-based extension point. spree_core's block does a full array
# *reassignment* (`= [...]`), so this has to run after it (append, don't
# replace) or the addition gets silently wiped — safe here because
# spree_doordash loads after spree/spree_core in the Gemfile, and Rails
# runs `after_initialize` blocks in engine-load order.
Rails.application.config.after_initialize do
  Rails.application.config.spree.calculators.shipping_methods << Spree::Calculator::Shipping::DoordashQuote
end
