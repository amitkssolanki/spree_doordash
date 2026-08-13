FactoryBot.define do
  # Define your Spree extensions Factories within this file to enable applications, and other extensions to use and override them.
  #
  # Example adding this to your spec_helper will load these Factories for use:
  # require 'spree_doordash/factories'

  factory :doordash_credential, class: 'SpreeDoordash::Credential' do
    store
    developer_id { 'test-developer-id' }
    key_id { 'test-key-id' }
    signing_secret { Base64.strict_encode64('test-signing-secret') }
    doordash_environment { 'sandbox' }
    webhook_basic_auth_token { 'Basic dGVzdDp0ZXN0' }
  end
end
