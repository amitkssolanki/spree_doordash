# Changelog

All notable changes to this project are documented here.

## 0.1.0 (unreleased)

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
