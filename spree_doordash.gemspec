# encoding: UTF-8
lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_doordash/version'

Gem::Specification.new do |s|
  s.platform    = Gem::Platform::RUBY
  s.name        = 'spree_doordash'
  s.version     = SpreeDoordash::VERSION
  s.summary     = 'Spree Commerce DoorDash Drive Extension'
  s.description = 'Dispatches completed Spree orders as DoorDash Drive deliveries — live delivery-fee ' \
                   'quoting during checkout, dispatch on order completion, and delivery status synced ' \
                   'back via webhooks. Companion extension to spree_square, keyed off the same ' \
                   'per-location mapping pattern.'
  s.required_ruby_version = '>= 3.2'

  s.author    = 'Amit Solanki'
  s.email     = 'amit@prayantr.com'
  s.homepage  = 'https://github.com/amitkssolanki/spree_doordash'
  s.license   = 'MIT'

  s.metadata = {
    'homepage_uri' => s.homepage,
    'source_code_uri' => s.homepage,
    'changelog_uri' => "#{s.homepage}/blob/main/CHANGELOG.md",
    'bug_tracker_uri' => "#{s.homepage}/issues"
  }

  s.files = `git ls-files -z`.split("\x0").reject do |f|
    f.start_with?('spec/') && !f.start_with?('spec/fixtures')
  end
  s.require_path = 'lib'
  s.requirements << 'none'

  spree_version = '>= 5.4.0.beta'
  s.add_dependency 'spree', spree_version
  s.add_dependency 'spree_admin', spree_version

  # DoorDash has no official Ruby SDK — plain JWT signing (HS256) against
  # openapi.doordash.com/drive/v2 via Faraday, already a transitive
  # dependency through Spree itself.
  s.add_dependency 'jwt', '~> 3.1'

  s.add_development_dependency 'spree_dev_tools'
  s.add_development_dependency 'webmock'
  s.add_development_dependency 'gem-release'
end
