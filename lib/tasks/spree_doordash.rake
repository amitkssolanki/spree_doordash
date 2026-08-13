namespace :spree_doordash do
  # M1 verification: proves the JWT this extension signs is actually
  # accepted by a real DoorDash Sandbox endpoint, not just shaped correctly
  # per the documented recipe (already covered by spec/services/spree_doordash/client_spec.rb).
  # Reads real credentials from .env.sandbox (gitignored, never committed —
  # see that file's own comment) rather than the encrypted
  # SpreeDoordash::Credential row, so this can run standalone against the
  # gem's own dummy app without needing a full spree_host install first.
  #
  # Usage:
  #   bin/rails spree_doordash:verify_connection
  desc 'Verify DoorDash Sandbox credentials by requesting a real delivery quote'
  task verify_connection: :environment do
    env_path = File.expand_path('../../.env.sandbox', __dir__)
    unless File.exist?(env_path)
      abort "No .env.sandbox found at #{env_path} — see README.md's \"Connecting to DoorDash\" section."
    end

    require 'dotenv'
    Dotenv.load(env_path)

    %w[DOORDASH_DEVELOPER_ID DOORDASH_KEY_ID DOORDASH_SIGNING_SECRET].each do |key|
      abort "#{key} is blank in .env.sandbox — fill in all three values first." if ENV[key].blank?
    end

    credential = SpreeDoordash::Credential.new(
      developer_id: ENV['DOORDASH_DEVELOPER_ID'],
      key_id: ENV['DOORDASH_KEY_ID'],
      signing_secret: ENV['DOORDASH_SIGNING_SECRET'],
      doordash_environment: 'sandbox'
    )
    client = SpreeDoordash::Client.new(credential: credential)

    # A quote is the safest possible real call to verify against — DoorDash's
    # own docs describe it as side-effect-light (no delivery is created,
    # nothing to clean up afterward), and it's the same payload shape M2's
    # SpreeDoordash::Quote service will build for real.
    payload = {
      external_delivery_id: "verify-#{SecureRandom.hex(4)}",
      pickup_address: '901 Market Street 6th Floor San Francisco, CA 94103',
      pickup_business_name: 'Spree Doordash Verification',
      pickup_phone_number: '+16505555555',
      dropoff_address: '901 Market Street 6th Floor San Francisco, CA 94103',
      dropoff_phone_number: '+16505555555',
      order_value: 1999
    }

    puts 'Requesting a Sandbox quote from DoorDash...'
    begin
      result = client.create_quote(payload)
      puts '✅ Success — DoorDash accepted the JWT and returned a real quote:'
      puts JSON.pretty_generate(result)
    rescue SpreeDoordash::RequestError => e
      puts "❌ DoorDash rejected the request (HTTP #{e.status}):"
      puts JSON.pretty_generate(e.body)
      exit 1
    end
  end

  desc 'Map a Spree stock location to a DoorDash store (M5 — a rake task, not a full admin CRUD screen: restaurants have a handful of locations, not hundreds)'
  task :map_location, %i[stock_location doordash_store_id doordash_business_id] => :environment do |_t, args|
    unless args[:stock_location] && args[:doordash_store_id]
      abort <<~USAGE
        Usage:
          bin/rails "spree_doordash:map_location[stock_location_id_or_name,doordash_store_id,doordash_business_id]"

        doordash_business_id defaults to "default" — DoorDash Sandbox
        auto-assigns a "default" business/store to every access key, so this
        is normally all you need there. Only pass a real business id once
        you've done full Business/Store API onboarding for production.
      USAGE
    end

    stock_location = Spree::StockLocation.find_by(id: args[:stock_location]) ||
                      Spree::StockLocation.find_by(name: args[:stock_location])
    abort "No stock location found matching '#{args[:stock_location]}'" unless stock_location

    # Spree::StockLocation has no store association of its own in this
    # Spree version (confirmed by reading the model — stock locations
    # aren't Store-scoped) — same single-default-store scope as the rest
    # of this extension (see SpreeDoordash::Quote's own order.store ||
    # Spree::Store.default).
    store = Spree::Store.default
    mapping = SpreeDoordash::LocationMapping.find_or_initialize_by(stock_location: stock_location)
    mapping.assign_attributes(
      store: store,
      doordash_store_id: args[:doordash_store_id],
      doordash_business_id: args[:doordash_business_id].presence || 'default'
    )
    mapping.save!

    puts "✅ Mapped '#{stock_location.name}' -> DoorDash store #{mapping.doordash_store_id} (business #{mapping.doordash_business_id})"
  end
end
