Spree::Core::Engine.add_routes do
  # `isolate_namespace Spree` in the engine means a normal `namespace
  # :spree_doordash do ... end` block would resolve controllers as
  # `Spree::SpreeDoordash::...` (the isolated module gets prepended). The
  # leading `/` on the controller path makes it absolute, resolving to the
  # actual `SpreeDoordash::WebhooksController` while keeping the URL prefix
  # — same pattern as spree_square's webhook route.
  post 'spree_doordash/webhooks/doordash', to: '/spree_doordash/webhooks#create'

  namespace :admin do
    # Plain credential-entry form (developer_id/key_id/signing_secret/webhook
    # Basic Auth token), not an OAuth connect/disconnect flow — DoorDash has
    # no refresh-token dance the way Square's OAuth does. Explicit named
    # routes rather than `resource :doordash_credential` since there's no
    # `new`/`create` — just show the one row for the current store and
    # update it in place, `find_or_initialize_by(store:)` style.
    get 'doordash_credential' => 'doordash_credentials#show', as: :doordash_credential
    patch 'doordash_credential' => 'doordash_credentials#update'

    # M5 — admin support/diagnostic pages, same read-only shape as
    # spree_square's own (:index only).
    resources :doordash_delivery_mappings, only: [:index]
    resources :doordash_webhook_events, only: [:index]
  end
end
