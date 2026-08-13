module SpreeDoordash
  # Verifies inbound DoorDash webhooks. Architecturally different from
  # SpreeSquare::WebhookVerifier: DoorDash has no HMAC signing scheme for
  # webhooks. Per DoorDash's own docs (Configure your webhook in the
  # Portal): Basic Auth here means "enter the contents you'd like DoorDash
  # to send in the HTTP Authorization header" — a static string DoorDash
  # echoes back verbatim on every call, not a credential DoorDash itself
  # authenticates. Comparison is still constant-time to avoid a timing
  # oracle on that string.
  class WebhookVerifier
    def self.valid?(authorization_header:, expected_token:)
      return false if authorization_header.blank? || expected_token.blank?

      ActiveSupport::SecurityUtils.secure_compare(authorization_header, expected_token)
    end
  end
end
