# Changelog

All notable changes to this project are documented here.

## 0.1.3

A real bug found live: the `doordash_quote_unavailable` warning added in 0.1.2 never actually
worked in production. `Spree::Calculator::Shipping::DoordashQuote#compute_package` pushed it onto
`package.order.warnings` — but `package.order` is **not** the same in-memory object as the order
the caller (`Spree::Order#create_proposed_shipments`) holds. `spree_core`'s own
`Spree::Stock::InventoryUnitBuilder#units` builds each inventory unit with `order_id: @order.id`
but deliberately *not* `order: @order` ("avoid loading the association to order until needed," per
its own comment) — the first thing that touches `.order` on one of those units triggers a fresh
`Spree::Order.find`, a brand-new Ruby object. So the warning was mutating a throwaway copy,
discarded the instant `compute_package` returned, and never reached the order this request
actually serializes back to the storefront as `cart.warnings`. Confirmed via `object_id` tracing
against production, not assumed — and confirmed the existing spec suite couldn't have caught it:
`doordash_quote_spec.rb`'s own `instance_double(Spree::Stock::Package, order: order)` makes
`package.order` the *same* object as the test's `order` by construction, sidestepping the exact
boundary that breaks in real Spree core.

Fixed by bridging across that boundary with the order's stable id instead of Ruby object identity
— `Spree::Calculator::Shipping::DoordashQuote.mark_unavailable(order_id)` sets a thread-local flag
(chosen over `Rails.cache`: this gem installs into arbitrary host apps, some of which legitimately
run `config.cache_store = :null_store`, which would silently degrade this back to the original bug
with zero indication anything was wrong — `compute_package` and `create_proposed_shipments` always
run synchronously on the same thread within one request, so a thread-local needs no external store
and no expiry logic). A new `Spree::OrderDecorator#create_proposed_shipments` reads the flag back
and merges the warning onto `self.warnings` immediately after `super` returns — `self` there *is*
the real order, since `create_proposed_shipments` is called directly on it by the checkout flow.
The flag is cleared unconditionally at the *start* of every call (not just after a successful
merge), so a stale flag left behind by an earlier request that raised before reaching the merge
step can never leak into a later, unrelated call that happens to reuse the same thread.

New `spec/models/spree/order_decorator_spec.rb` exercises the real
`order_routing_strategy -> Estimator -> Packer -> InventoryUnitBuilder` path end to end (only
`SpreeDoordash::Quote.call` is stubbed) — the only way to actually exercise the object-identity
boundary the fix bridges across, rather than doubling it away. Full suite: 95 examples, 0 failures
(5 new). Coverage: 94.14%. Brakeman clean.

## 0.1.2

A real bug found live during checkout-validation work: a blank phone on the dropoff address used
to fall back to a fake placeholder number (`+10000000000`) that DoorDash's API rejected anyway —
the request was doomed before it was even built, and (same as the E.164 issue fixed in 0.1.1) the
DoorDash Delivery rate just silently vanished with no error anywhere in the UI.

- `SpreeDoordash::Quote#call` now returns early (no API call at all) when the ship address has no
  phone, instead of building a request known to fail. `format_phone`'s placeholder fallback is
  removed entirely.
- `Spree::Calculator::Shipping::DoordashQuote#compute_package` now pushes a
  `doordash_quote_unavailable` warning onto `Spree::Order#warnings` whenever `SpreeDoordash::Quote`
  returns `nil` — generic to *why* the quote failed (bad/missing phone, an address DoorDash
  genuinely can't serve, DoorDash API down), confirmed live for two different real causes.
  `Spree::Order#warnings` is the same transient mechanism core's own
  `ensure_available_shipping_rates` already uses for the identical class of problem, and flows
  through to the Store API's `cart.warnings` with no new API surface. A storefront reference
  implementation now renders this as a real, non-blocking banner instead of silence — see
  `spree_storefront_web`'s `DeliveryMethodSection.tsx`.

Full suite: 90 examples, 0 failures (2 new). Coverage: 94.14% (241/256 lines). Brakeman clean.

## 0.1.1

Two real production bugs, both invisible to the full spec suite and to every prior "live
verification" in this project, both found only by driving a genuine storefront checkout end to
end instead of calling the services directly:

- **DoorDash rejects any phone number that isn't strict E.164.** Every earlier live test in this
  project — including the M1–M5 verifications documented below — happened to type phone numbers
  directly in `+1XXXXXXXXXX` form. The first real checkout, with a number typed the way an address
  form actually produces one (`(202) 555-0199`), got a real `400 Unknown phone number format` from
  DoorDash's `/drive/v2/quotes` endpoint — which silently dropped the DoorDash Delivery shipping
  rate with no error surfaced anywhere in checkout. Fixed by normalizing both `pickup_phone_number`
  and `dropoff_phone_number` to E.164 before every quote request.

- **The order-completed subscriber was never actually registered with Spree's event system.**
  `Spree::Subscriber`'s own docstring claims subscribers are "automatically registered during Rails
  initialization" — that's not what `spree_core` 5.6.1 actually does. `Spree::Events.register_subscribers!`
  only iterates an explicit `Spree.subscribers` array, populated via `Spree.subscribers << YourClass`
  in an initializer; there's no automatic scan. This gem never had that initializer line. Every spec
  for `OrderCompletedSubscriber` called `.call` on it directly, which bypasses the registry entirely
  and kept passing regardless — so a real storefront order, placed with DoorDash Delivery selected,
  completed successfully and was never dispatched, with nothing anywhere indicating a problem. Fixed
  by adding the missing `config/initializers/spree.rb`, plus a new spec that asserts
  `Spree.subscribers` actually includes the class — the one test that would have caught this from
  the start.

## 0.1.0

Initial development. M1 (foundation) — complete and verified against a real DoorDash Sandbox
endpoint (`bin/rails spree_doordash:verify_connection`, a real accepted quote):
`SpreeDoordash::Credential` (encrypted per-store DoorDash Drive access key),
`SpreeDoordash::Client` (JWT signing against the Drive v2 API), and a plain credential-entry
admin form.

Two real JWT-signing bugs only surfaced by that live verification, not by DoorDash's own docs or
sample code:
- The signing secret must be **base64url**-decoded, not standard base64.
- The JWT header needs an explicit `typ: 'JWT'` field — the `jwt` gem doesn't add it
  automatically the way Node's `jsonwebtoken` (what DoorDash's own sample code uses) does.

M2 — `SpreeDoordash::LocationMapping` (stock location ↔ DoorDash store), `SpreeDoordash::Quote`
(builds and persists a live delivery-fee quote for an order). Found and fixed a real ActiveRecord
association-caching bug: creating a shipment via `create(:shipment, order:, ...)` (setting the FK
directly) doesn't invalidate an already-loaded `order.shipments` association — fixed by querying
`Spree::Shipment.where(order_id:)` directly rather than `order.shipments.first`.

M3 — `Spree::Calculator::Shipping::DoordashQuote`, wiring a live quote into checkout as an
ordinary shipping rate; verified end to end against a real order and a real Sandbox quote
($9.75 for a real DC address). Two real things caught only by that live wiring:
- `Spree::ShippingMethod.calculators` does **not** auto-discover `ShippingCalculator` subclasses —
  it reads a hardcoded array `spree_core` populates via its own `config.after_initialize`;
  registering the new calculator needed an explicit append in a later-running initializer.
- Re-quoting the same order (which checkout does on essentially every step) with a stable
  `external_delivery_id` gets rejected by DoorDash's real API with `409 duplicate_delivery_id`,
  even though the prior quote is still open — fixed by appending a random suffix per quote
  attempt.

M4 — `SpreeDoordash::DeliveryDispatcher` (accept-or-requote-then-accept), the full webhook chain
(`WebhooksController`, Basic-Auth `WebhookVerifier`, idempotent `WebhookEvent`,
`DeliveryStatusMapper`). Verified live via ngrok + DoorDash's Sandbox Delivery Simulator: the full
`DASHER_CONFIRMED` → … → `DASHER_DROPPED_OFF` event sequence, and a `DELIVERY_CANCELLED` path,
both against real dispatched orders — confirmed `shipment.ship!` and `order.cancel!` actually
fire on the real captured payloads. Fixed a `NOT NULL` constraint that broke
`DeliveryDispatchJob`'s own dead-letter failure recording.

M5 — Admin pages (DoorDash Deliveries, DoorDash Webhooks) and a `spree_doordash:map_location`
rake task. Two real bugs found only by loading the pages against a real Postgres-backed app (the
SQLite dummy app used for specs has neither problem):
- Postgres' plain `json` type has no equality operator, and `spree_admin`'s table view issues
  `SELECT DISTINCT` — every `json` column in this gem 500'd its own admin page. Fixed by using
  `jsonb` on Postgres (matching `spree_core`'s own migration convention), plain `json` on SQLite.
- `Spree.admin.tables.register` defaults to expecting a `:new` route that doesn't exist on a
  read-only resource — 500'd the instant a table was empty. Fixed with `new_resource: false`.

⚠️ DoorDash Drive API production access is currently restricted by DoorDash (no committed
timeline) — this extension targets and is verified against **Sandbox** only until that changes.
