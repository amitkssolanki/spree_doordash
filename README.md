# Spree DoorDash

This is a [DoorDash Drive](https://developer.doordash.com) delivery extension for [Spree Commerce](https://spreecommerce.org), an open source e-commerce platform built with Ruby on Rails. It's the companion to [`spree_square`](https://github.com/amitkssolanki/spree_square) — quotes and dispatches DoorDash Drive deliveries for completed Spree orders, keyed off each order's fulfilling location.

> ⚠️ **DoorDash Drive API production access is currently restricted by DoorDash**, with no committed timeline — see their [Get Started guide](https://developer.doordash.com/en-US/docs/drive/tutorials/get_started/). Sandbox is fully open. This extension is built and verified against Sandbox; going live requires DoorDash's separate approval.

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
3. (Once wired up in a later milestone) configure a webhook endpoint for delivery status updates
   in the Developer Portal's **Webhooks** page, protected with Basic Auth — paste that same header
   value into the **Webhook Basic Auth value** field on the same connection page.

Access keys created before requesting production access are Sandbox-only — you can build and
fully test this extension's entire flow (quotes, dispatch, status webhooks, DoorDash's own
[Delivery Simulator](https://developer.doordash.com)) without ever needing production approval.

## Development

```bash
bundle install
bundle exec rake test_app   # generates spec/dummy
bundle exec rspec
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full contribution/release workflow.
