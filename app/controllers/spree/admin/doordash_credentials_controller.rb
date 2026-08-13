module Spree
  module Admin
    # Plain credential-entry form for the current store's DoorDash Drive
    # access key — not an OAuth connect/disconnect flow like Square's.
    # DoorDash Drive auth has no redirect dance: an admin creates an access
    # key once in DoorDash's Developer Portal and pastes the three values in
    # here directly (encrypted at rest — see SpreeDoordash::Credential).
    class DoordashCredentialsController < Spree::Admin::BaseController
      def show
        @credential = SpreeDoordash::Credential.find_or_initialize_by(store: current_store)
      end

      def update
        @credential = SpreeDoordash::Credential.find_or_initialize_by(store: current_store)

        if @credential.update(credential_params)
          flash[:success] = Spree.t(:doordash_credential_saved, default: 'DoorDash credentials saved.')
        else
          flash[:error] = @credential.errors.full_messages.to_sentence
        end

        redirect_to admin_doordash_credential_path
      end

      private

      # Blank secret fields mean "leave unchanged" (the form always renders
      # them empty and never echoes the current value back) — submitting an
      # actually-blank value would otherwise silently overwrite a working
      # credential with an empty string on every save.
      def credential_params
        permitted = params.require(:spree_doordash_credential).permit(
          :developer_id, :key_id, :signing_secret, :webhook_basic_auth_token, :doordash_environment
        )
        %i[signing_secret webhook_basic_auth_token].each do |field|
          permitted.delete(field) if permitted[field].blank?
        end
        permitted
      end
    end
  end
end
