module SpreeDoordash
  # One place for "this needs a human" — used when a job exhausts its
  # retries. A standalone copy of SpreeSquare::Alerting's pattern rather
  # than a dependency on that gem — spree_doordash stays independently
  # installable on its own. Reports to Sentry when available, always logs
  # at error level regardless so nothing depends on Sentry being configured
  # to at least be visible in the server log.
  class Alerting
    def self.capture(error, context: {})
      context = { source: 'spree_doordash' }.merge(context.is_a?(String) ? { area: context } : context)

      Rails.logger.error("[SpreeDoordash] #{context[:area] || 'error'}: #{error.class}: #{error.message}")

      return unless defined?(Sentry)

      Sentry.capture_exception(error, extra: context)
    end
  end
end
