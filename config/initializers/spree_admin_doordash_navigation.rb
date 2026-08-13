Rails.application.config.after_initialize do
  # Position 68 — right after spree_square's own entries (65-67), so the two
  # extensions' nav items sit together without colliding.
  Spree.admin.navigation.sidebar.add :doordash_credential,
    label: 'DoorDash Connection',
    url: :admin_doordash_credential_path,
    icon: 'plug',
    position: 68,
    active: -> { controller_name == 'doordash_credentials' },
    if: -> { can?(:manage, SpreeDoordash::Credential) }
end
