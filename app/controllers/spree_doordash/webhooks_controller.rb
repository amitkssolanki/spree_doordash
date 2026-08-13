module SpreeDoordash
  # Receives DoorDash Drive webhook notifications. Basic-Auth-verified
  # instead of Square's HMAC signature (see SpreeDoordash::WebhookVerifier)
  # and, like SpreeSquare::WebhooksController, deliberately does the least
  # possible work synchronously: verify, record, ack, hand off to a job.
  # DoorDash "sends each webhook event up to 3 times" on anything other
  # than 200 (its own docs), so a slow or non-2xx response means retries.
  class WebhooksController < ActionController::Base
    # Explicit, not just `skip_before_action :verify_authenticity_token` —
    # this controller doesn't inherit the host app's ApplicationController
    # (where `protect_from_forgery` normally gets declared), so a static
    # analyzer (Brakeman) correctly flags it as never actually configured
    # either way — confirmed by the identical warning on spree_square's own
    # WebhooksController. `:null_session` degrades a forged/missing token
    # to an empty session instead of raising — appropriate here since this
    # endpoint is Basic-Auth-verified, not session-authenticated.
    protect_from_forgery with: :null_session

    def create
      credential = SpreeDoordash::Credential.find_by(store: Spree::Store.default)

      unless SpreeDoordash::WebhookVerifier.valid?(
        authorization_header: request.headers['Authorization'],
        expected_token: credential&.webhook_basic_auth_token
      )
        Rails.logger.warn('[SpreeDoordash] webhook auth verification failed')
        return head :unauthorized
      end

      raw_body = request.raw_post
      payload = JSON.parse(raw_body)
      event = find_or_log_event(raw_body, payload)
      SpreeDoordash::DeliveryWebhookJob.perform_later(event.id) if event.previously_new_record?

      head :ok
    rescue JSON::ParserError
      head :bad_request
    end

    private

    def find_or_log_event(raw_body, payload)
      SpreeDoordash::WebhookEvent.find_or_create_by!(
        external_delivery_id: payload['external_delivery_id'],
        event_name: payload['event_name'],
        payload_digest: SpreeDoordash::WebhookEvent.digest(raw_body)
      ) do |event|
        event.payload = payload
      end
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # Lost a race with a concurrent duplicate delivery — the row exists
      # now either way, and it's already being (or has been) processed once.
      SpreeDoordash::WebhookEvent.find_by!(
        external_delivery_id: payload['external_delivery_id'],
        event_name: payload['event_name'],
        payload_digest: SpreeDoordash::WebhookEvent.digest(raw_body)
      )
    end
  end
end
