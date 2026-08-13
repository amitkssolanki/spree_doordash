module SpreeDoordash
  class Engine < Rails::Engine
    require 'spree/core'
    isolate_namespace Spree
    engine_name 'spree_doordash'

    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'spree_doordash.environment', before: :load_config_initializers do |_app|
      SpreeDoordash::Config = SpreeDoordash::Configuration.new
    end

    # Same ordering requirement as spree_square's identical initializer —
    # must run before Active Record's own "active_record_encryption.configuration"
    # initializer reads config.active_record.encryption, or Credential's
    # encrypted columns fail with "Missing Active Record encryption
    # credential" the first time they're touched. Shares the same
    # ACTIVE_RECORD_ENCRYPTION_* keys spree_square already sets up (one
    # encryption key set per Rails app, not per extension).
    initializer 'spree_doordash.active_record_encryption', before: 'active_record_encryption.configuration' do |app|
      next if ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'].blank?

      app.config.active_record.encryption.primary_key = ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY']
      app.config.active_record.encryption.deterministic_key = ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY']
      app.config.active_record.encryption.key_derivation_salt = ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT']
    end

    # Force-loads decorator files the same way spree_square's engine does —
    # not needed until this extension actually has a decorator (M3+), kept
    # here from the start so adding one later doesn't require remembering
    # this step. See spree_square/lib/spree_square/engine.rb for the full
    # rationale (Zeitwerk lazy-autoloading never triggers a decorator file's
    # `prepend` line otherwise).
    def self.activate
      Dir.glob(File.join(File.dirname(__FILE__), '../../app/**/*_decorator*.rb')) do |c|
        Rails.application.config.cache_classes ? require(c) : load(c)
      end
    end

    config.to_prepare(&method(:activate).to_proc)
  end
end
