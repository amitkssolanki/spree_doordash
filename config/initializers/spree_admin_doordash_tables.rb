Rails.application.config.after_initialize do
  # new_resource: false — read-only support/diagnostic tables (no
  # `:new`/`:create` route exists; only: [:index] in config/routes.rb). The
  # default (true) crashes with a routing error the moment the table is
  # ever empty — found live, not from spree_admin's own docs — because the
  # "no resource found" empty-state partial builds a `new_object_url` link
  # unconditionally unless told not to. Same latent exposure exists in
  # spree_square's own admin tables (they don't set this either); flagged
  # separately rather than silently fixed here since that's a different gem.
  Spree.admin.tables.register(:doordash_delivery_mappings, model_class: SpreeDoordash::DeliveryMapping,
                                                             search_param: :external_delivery_id_cont, new_resource: false)

  Spree.admin.tables.doordash_delivery_mappings.add :order_number,
    label: :order,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 10,
    method: ->(mapping) { mapping.order&.number }

  Spree.admin.tables.doordash_delivery_mappings.add :external_delivery_id,
    label: :external_delivery_id,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 20

  Spree.admin.tables.doordash_delivery_mappings.add :last_status,
    label: :status,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 30

  Spree.admin.tables.doordash_delivery_mappings.add :tracking_url,
    label: :tracking_url,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 40

  Spree.admin.tables.doordash_delivery_mappings.add :dasher_name,
    label: :dasher,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 50

  Spree.admin.tables.doordash_delivery_mappings.add :dispatch_error,
    label: :dispatch_error,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 60

  Spree.admin.tables.doordash_delivery_mappings.add :created_at,
    label: :created_at,
    type: :datetime,
    sortable: true,
    filterable: false,
    default: true,
    position: 70

  Spree.admin.tables.register(:doordash_webhook_events, model_class: SpreeDoordash::WebhookEvent,
                                                          search_param: :event_name_cont, new_resource: false)

  Spree.admin.tables.doordash_webhook_events.add :external_delivery_id,
    label: :external_delivery_id,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 10

  Spree.admin.tables.doordash_webhook_events.add :event_name,
    label: :event_name,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 20

  Spree.admin.tables.doordash_webhook_events.add :status,
    label: :status,
    type: :string,
    sortable: true,
    filterable: true,
    default: true,
    position: 30

  Spree.admin.tables.doordash_webhook_events.add :processed_at,
    label: :processed_at,
    type: :datetime,
    sortable: true,
    filterable: false,
    default: true,
    position: 40

  Spree.admin.tables.doordash_webhook_events.add :error_message,
    label: :error_message,
    type: :string,
    sortable: false,
    filterable: false,
    default: true,
    position: 50

  Spree.admin.tables.doordash_webhook_events.add :created_at,
    label: :received_at,
    type: :datetime,
    sortable: true,
    filterable: false,
    default: true,
    position: 60
end
