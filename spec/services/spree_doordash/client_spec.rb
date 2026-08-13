RSpec.describe SpreeDoordash::Client do
  let!(:credential) { create(:doordash_credential, store: store) }
  let(:store) { create(:store) }

  describe '.instance / .for_store' do
    it 'raises MissingCredentialsError when the store has no connected credential' do
      expect { described_class.for_store(create(:store)) }.to raise_error(described_class::MissingCredentialsError)
    end

    it 'resolves against the given store credential' do
      client = described_class.for_store(store)
      expect(client).to be_sandbox
    end

    it 'is not memoized — re-resolves the credential on every call' do
      described_class.for_store(store) # warms nothing, since there's no caching to warm
      credential.destroy!
      expect { described_class.for_store(store) }.to raise_error(described_class::MissingCredentialsError)
    end
  end

  describe '#create_quote' do
    it 'signs a JWT with the claims and header DoorDash documents, and posts the payload' do
      client = described_class.for_store(store)

      stub = stub_request(:post, 'https://openapi.doordash.com/drive/v2/quotes')
             .with { |req|
               token = req.headers['Authorization'].to_s.sub(/^Bearer /, '')
               header = JWT.decode(token, nil, false).last
               payload = JWT.decode(token, Base64.urlsafe_decode64(credential.signing_secret), true, algorithm: 'HS256').first

               # Both of these were verified directly against a real DoorDash
               # Sandbox endpoint, not just DoorDash's docs — the first live
               # request came back 401 twice, once for each: the signing
               # secret must be base64url-decoded (not standard base64,
               # despite DoorDash's own JS sample code implying either
               # works), and `typ: 'JWT'` must be explicit in the header
               # (the `jwt` gem doesn't add it automatically the way Node's
               # jsonwebtoken — what DoorDash's sample code uses — does).
               expect(header['typ']).to eq('JWT')
               expect(header['dd-ver']).to eq('DD-JWT-V1')
               expect(payload['aud']).to eq('doordash')
               expect(payload['iss']).to eq(credential.developer_id)
               expect(payload['kid']).to eq(credential.key_id)
               expect(payload['exp'] - payload['iat']).to eq(SpreeDoordash::Client::JWT_TTL)
               true
             }
             .to_return(status: 200, body: { delivery_status: 'quote', fee: 599 }.to_json, headers: { 'Content-Type' => 'application/json' })

      result = client.create_quote(external_delivery_id: 'order-1')

      expect(stub).to have_been_requested
      expect(result['fee']).to eq(599)
    end

    it 'raises RequestError with the status and parsed body on a non-2xx response' do
      client = described_class.for_store(store)
      stub_request(:post, 'https://openapi.doordash.com/drive/v2/quotes')
        .to_return(status: 401, body: { type: 'authentication_error', message: 'bad token' }.to_json)

      expect { client.create_quote({}) }.to raise_error(SpreeDoordash::RequestError) do |error|
        expect(error.status).to eq(401)
        expect(error.body['message']).to eq('bad token')
      end
    end
  end
end
