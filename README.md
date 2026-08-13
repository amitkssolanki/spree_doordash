# Spree DoorDash

[![Gem Version](https://img.shields.io/gem/v/spree_doordash.svg)](https://rubygems.org/gems/spree_doordash)
[![GitHub Release](https://img.shields.io/github/v/release/amitkssolanki/spree_doordash)](https://github.com/amitkssolanki/spree_doordash/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)

This is a [DoorDash Drive](https://developer.doordash.com) delivery extension for [Spree Commerce](https://spreecommerce.org), an open source e-commerce platform built with Ruby on Rails. It's the companion to [`spree_square`](https://github.com/amitkssolanki/spree_square) — quotes and dispatches DoorDash Drive deliveries for completed Spree orders, keyed off each order's fulfilling location.

> ⚠️ **DoorDash Drive API production access is currently restricted by DoorDash**, with no committed timeline — see their [Get Started guide](https://developer.doordash.com/en-US/docs/drive/tutorials/get_started/). Sandbox is fully open, and this extension's entire flow (live quoting, dispatch, webhook-driven status sync, admin diagnostics) is built and verified end to end against Sandbox — including DoorDash's own [Delivery Simulator](https://developer.doordash.com) — without ever needing production approval. Going live requires DoorDash's separate approval on their own timeline.

## What this does

- **Live delivery-fee quoting at checkout** — `Spree::Calculator::Shipping::DoordashQuote` requests
  a real DoorDash quote and shows it as an ordinary shipping rate, no custom storefront code
  needed.
- **Dispatch on order completion** — accepts the checkout-time quote (re-quoting first if it's
  expired; DoorDash quotes are only valid 5 minutes) and creates the real delivery.
- **Delivery status synced back via webhooks** — a Dasher picking up/dropping off/canceling the
  order updates the Spree shipment/order state automatically.
- **Admin visibility** — DoorDash Deliveries and DoorDash Webhooks pages for support/diagnostics.

## Installation

1. Add this extension to your Gemfile with this line:

    ```ruby
    bundle add spree_doordash
    ```

2. Run the install generator

    ```ruby
    bundle exec rails g spree_doordash:install
    ```

3. Restart your server

  If your server was running, restart it so that it can find the assets properly.

## Connecting to DoorDash

DoorDash Drive auth has no OAuth/refresh flow — a static access key, created once, signs a fresh
short-lived JWT on every API call:

1. Create a [DoorDash Developer Portal](https://developer.doordash.com) account and create an
   access key (**Credentials** in the left nav). This gives you a `developer_id`, `key_id`, and
   `signing_secret`.
2. In your Spree admin, go to **DoorDash Connection** in the sidebar and paste the three values
   in. They're encrypted at rest ([ActiveRecord::Encryption](https://guides.rubyonrails.org/active_record_encryption.html)) —
   same mechanism `spree_square` uses for its own credentials, sharing the same
   `ACTIVE_RECORD_ENCRYPTION_*` keys.
3. Configure a webhook endpoint for delivery status updates in the Developer Portal's
   **Webhooks** page (Sandbox and Production each support one endpoint), protected with Basic
   Auth. Paste that exact `Authorization` header value into the **Webhook Basic Auth value**
   field on the same connection page — it's a static string DoorDash echoes back verbatim on
   every webhook, not a credential DoorDash itself authenticates.
4. Point the webhook URL at `POST /spree_doordash/webhooks/doordash` on your store (needs to be
   internet-reachable — `ngrok`/`cloudflared` for local dev).

Access keys created before requesting production access are Sandbox-only — you can build and
fully test this extension's entire flow (quotes, dispatch, status webhooks, DoorDash's own
[Delivery Simulator](https://developer.doordash.com)) without ever needing production approval.

## Setting up a DoorDash Delivery shipping method

1. Map each fulfilling stock location to a DoorDash store:

    ```bash
    bin/rails "spree_doordash:map_location[stock_location_id_or_name,doordash_store_id,doordash_business_id]"
    ```

    `doordash_business_id` defaults to `"default"` — DoorDash Sandbox auto-assigns a default
    business/store to every access key, so that's normally all you need there.

2. In **Settings → Shipping Methods**, create a new shipping method (e.g. "DoorDash Delivery")
   with calculator **DoordashQuote**, attached to whichever zone/shipping category your delivery
   orders use. `Spree::Stock::Estimator` picks it up automatically — no further wiring needed;
   any code path that estimates shipping rates for an order (checkout, admin, API) will now
   request a live quote for that rate whenever the order has a ship address.

## Development

```bash
bundle install
bundle exec rake test_app   # generates spec/dummy
bundle exec rspec
```

When testing your application's integration with this extension you may use its factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_doordash/factories'
```

## Releasing a new version

```shell
bundle exec gem bump -p -t
bundle exec gem release
```

For more options please see [gem-release README](https://github.com/svenfuchs/gem-release)

## Contributing

If you'd like to contribute, please take a look at the
[instructions](CONTRIBUTING.md) for installing dependencies and crafting a good
pull request.
