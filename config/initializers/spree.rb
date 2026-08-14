# Registers this extension's event subscriber with Spree's event system.
#
# Spree::Subscriber's own docstring says subscribers are "automatically
# registered during Rails initialization" — that's not what actually
# happens in spree_core 5.6.1: Spree::Events.register_subscribers! only
# ever iterates the explicit Spree.subscribers array (see
# spree_core/lib/spree/events.rb) — there is no Zeitwerk-descendant scan.
# Without this file, SpreeDoordash::OrderCompletedSubscriber is a real,
# loadable class (so specs calling it directly always passed) but is never
# actually wired to the 'order.completed' event in the running app — found
# live: a real storefront order completed with DoorDash Delivery selected
# and never got dispatched, because nothing ever appended this subscriber
# to Spree.subscribers. Mirrors spree_square's own identical registration
# in its own config/initializers/spree.rb.
Rails.application.config.after_initialize do
  Spree.subscribers << SpreeDoordash::OrderCompletedSubscriber
end
