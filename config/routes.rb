Spree::Core::Engine.add_routes do
  namespace :admin do
    # Plain credential-entry form (developer_id/key_id/signing_secret/webhook
    # Basic Auth token), not an OAuth connect/disconnect flow — DoorDash has
    # no refresh-token dance the way Square's OAuth does. Explicit named
    # routes rather than `resource :doordash_credential` since there's no
    # `new`/`create` — just show the one row for the current store and
    # update it in place, `find_or_initialize_by(store:)` style.
    get 'doordash_credential' => 'doordash_credentials#show', as: :doordash_credential
    patch 'doordash_credential' => 'doordash_credentials#update'

    # M4 will add: post 'spree_doordash/webhooks/doordash', to:
    # '/spree_doordash/webhooks#create' (same absolute-slash pattern as
    # spree_square's webhook route — isolate_namespace Spree means a plain
    # `namespace :spree_doordash do` block would resolve as
    # Spree::SpreeDoordash::..., not the real SpreeDoordash::... controller).
  end
end
