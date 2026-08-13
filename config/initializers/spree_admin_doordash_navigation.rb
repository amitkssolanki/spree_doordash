Rails.application.config.after_initialize do
  # Positions 68-70 — right after spree_square's own entries (65-67), so the
  # two extensions' nav items sit together without colliding.
  Spree.admin.navigation.sidebar.add :doordash_credential,
    label: 'DoorDash Connection',
    url: :admin_doordash_credential_path,
    icon: 'plug',
    position: 68,
    active: -> { controller_name == 'doordash_credentials' },
    if: -> { can?(:manage, SpreeDoordash::Credential) }

  Spree.admin.navigation.sidebar.add :doordash_delivery_mappings,
    label: 'DoorDash Deliveries',
    url: :admin_doordash_delivery_mappings_path,
    icon: 'truck',
    position: 69,
    active: -> { controller_name == 'doordash_delivery_mappings' },
    if: -> { can?(:manage, SpreeDoordash::DeliveryMapping) }

  Spree.admin.navigation.sidebar.add :doordash_webhook_events,
    label: 'DoorDash Webhooks',
    url: :admin_doordash_webhook_events_path,
    icon: 'webhook',
    position: 70,
    active: -> { controller_name == 'doordash_webhook_events' },
    if: -> { can?(:manage, SpreeDoordash::WebhookEvent) }
end
