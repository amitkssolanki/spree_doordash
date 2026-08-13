FactoryBot.define do
  # Define your Spree extensions Factories within this file to enable applications, and other extensions to use and override them.
  #
  # Example adding this to your spec_helper will load these Factories for use:
  # require 'spree_doordash/factories'

  factory :doordash_credential, class: 'SpreeDoordash::Credential' do
    store
    developer_id { 'test-developer-id' }
    key_id { 'test-key-id' }
    # base64url, matching what SpreeDoordash::Client actually decodes with
    # (Base64.urlsafe_decode64) — confirmed against a real DoorDash Sandbox
    # 401 that standard base64 is the wrong alphabet.
    signing_secret { Base64.urlsafe_encode64('test-signing-secret') }
    doordash_environment { 'sandbox' }
    webhook_basic_auth_token { 'Basic dGVzdDp0ZXN0' }
  end

  factory :doordash_location_mapping, class: 'SpreeDoordash::LocationMapping' do
    stock_location
    store
    sequence(:doordash_store_id) { |i| "DDSTORE#{i}" }
    doordash_business_id { 'default' }
  end

  factory :doordash_quote_mapping, class: 'SpreeDoordash::QuoteMapping' do
    order
    sequence(:external_delivery_id) { |i| "spree-doordash-R#{i}" }
    quoted_fee_cents { 599 }
    currency { 'USD' }
    quote_expires_at { 5.minutes.from_now }
  end

  factory :doordash_delivery_mapping, class: 'SpreeDoordash::DeliveryMapping' do
    order
    sequence(:external_delivery_id) { |i| "spree-doordash-R#{i}-accepted" }
    last_status { 'created' }
    tracking_url { 'https://doordash.com/tracking?id=abc123' }
  end

  factory :doordash_webhook_event, class: 'SpreeDoordash::WebhookEvent' do
    sequence(:external_delivery_id) { |i| "spree-doordash-R#{i}" }
    event_name { 'DASHER_CONFIRMED' }
    sequence(:payload_digest) { |i| "digest-#{i}" }
    payload { { 'event_name' => 'DASHER_CONFIRMED', 'external_delivery_id' => 'spree-doordash-R1' } }
  end
end
