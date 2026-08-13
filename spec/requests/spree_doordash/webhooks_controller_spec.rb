RSpec.describe 'SpreeDoordash webhooks', type: :request do
  let(:auth_token) { 'Basic dGVzdDp0ZXN0' }
  let(:path) { '/spree_doordash/webhooks/doordash' }
  let(:body) { { external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED' }.to_json }

  before do
    store = create(:store, default: true)
    create(:doordash_credential, store: store, webhook_basic_auth_token: auth_token)
  end

  def headers(token: auth_token)
    { 'Authorization' => token, 'CONTENT_TYPE' => 'application/json' }
  end

  it 'accepts a correctly authenticated payload and enqueues the delivery webhook job' do
    expect(SpreeDoordash::DeliveryWebhookJob).to receive(:perform_later)

    post path, params: body, headers: headers

    expect(response).to have_http_status(:ok)
    expect(SpreeDoordash::WebhookEvent.find_by(external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED')).to be_present
  end

  it 'rejects a request with the wrong Authorization header' do
    post path, params: body, headers: headers(token: 'Basic wrong')

    expect(response).to have_http_status(:unauthorized)
    expect(SpreeDoordash::WebhookEvent.find_by(external_delivery_id: 'del_1')).to be_nil
  end

  it 'rejects a request with no Authorization header at all' do
    post path, params: body, headers: { 'CONTENT_TYPE' => 'application/json' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'rejects every request when no credential is connected for the default store' do
    SpreeDoordash::Credential.destroy_all

    post path, params: body, headers: headers

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not enqueue a job twice for a duplicate delivery of the same event' do
    expect(SpreeDoordash::DeliveryWebhookJob).to receive(:perform_later).once

    2.times { post path, params: body, headers: headers }

    expect(response).to have_http_status(:ok)
    expect(SpreeDoordash::WebhookEvent.where(external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED').count).to eq(1)
  end

  it 'treats a redelivery with a genuinely different payload body as a distinct event, not a duplicate' do
    other_body = { external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED', dasher_name: 'Jamie D.' }.to_json

    expect(SpreeDoordash::DeliveryWebhookJob).to receive(:perform_later).twice

    post path, params: body, headers: headers
    post path, params: other_body, headers: headers

    expect(SpreeDoordash::WebhookEvent.where(external_delivery_id: 'del_1', event_name: 'DASHER_CONFIRMED').count).to eq(2)
  end

  it 'returns 400 for a body that is not valid JSON' do
    post path, params: '{not json', headers: headers

    expect(response).to have_http_status(:bad_request)
  end
end
