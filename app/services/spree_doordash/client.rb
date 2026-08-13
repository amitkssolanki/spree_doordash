require 'jwt'
require 'faraday'

module SpreeDoordash
  # Thin wrapper around the DoorDash Drive API (v2). All Drive API access in
  # this extension goes through here.
  #
  # Auth is fundamentally different from SpreeSquare::Client: DoorDash Drive
  # has no OAuth/refresh flow. A static access key (developer_id/key_id/
  # signing_secret), created once in DoorDash's Developer Portal, signs a
  # fresh short-lived (5 min) JWT on every call — there's nothing to cache
  # or refresh, unlike Square's 30-day access token.
  class Client
    class MissingCredentialsError < StandardError; end

    BASE_URL = 'https://openapi.doordash.com'.freeze
    JWT_TTL = 300 # seconds — matches DoorDash's own documented recipe

    # Deliberately NOT memoized, same rationale as SpreeSquare::Client: a
    # store's credential can be created/edited by an admin mid-process, and
    # nothing here is expensive enough to cache (a JWT is cheap to sign, and
    # is only valid 5 minutes anyway).
    def self.instance
      for_store
    end

    def self.for_store(store = Spree::Store.default)
      new(credential: SpreeDoordash::Credential.find_by(store: store))
    end

    def initialize(credential: nil)
      @credential = credential
      raise MissingCredentialsError, 'No DoorDash credential connected for this store' unless @credential
    end

    def sandbox?
      @credential.sandbox?
    end

    # Validates coverage/pricing for a delivery before formally creating it —
    # DoorDash's own recommended first call (see docs/how_to/quote_deliveries).
    # Quotes are valid 5 minutes; accept_quote (M2) formally creates the
    # delivery.
    def create_quote(payload)
      request(:post, '/drive/v2/quotes', payload)
    end

    private

    def request(method, path, body = nil)
      response = connection.send(method) do |req|
        req.url path
        req.headers['Authorization'] = "Bearer #{jwt}"
        req.headers['Content-Type'] = 'application/json'
        req.body = body.to_json if body
      end
      handle_response(response)
    end

    def connection
      @connection ||= Faraday.new(url: BASE_URL)
    end

    def handle_response(response)
      parsed = response.body.present? ? JSON.parse(response.body) : {}
      return parsed if response.status.between?(200, 299)

      raise RequestError.new("DoorDash API error (#{response.status}): #{parsed.inspect}", status: response.status, body: parsed)
    end

    # JWT claims exactly matching DoorDash's own documented recipe —
    # including `kid` living in the payload/claims rather than the JWT
    # header, which is non-standard (kid is normally a header parameter)
    # but is what DoorDash's API actually expects; `dd-ver` is the one true
    # header field.
    def jwt
      now = Time.now.to_i
      payload = {
        aud: 'doordash',
        iss: @credential.developer_id,
        kid: @credential.key_id,
        iat: now,
        exp: now + JWT_TTL
      }
      key = Base64.decode64(@credential.signing_secret)
      JWT.encode(payload, key, 'HS256', { 'dd-ver' => 'DD-JWT-V1' })
    end
  end

  class RequestError < StandardError
    attr_reader :status, :body

    def initialize(message, status:, body:)
      super(message)
      @status = status
      @body = body
    end
  end
end
