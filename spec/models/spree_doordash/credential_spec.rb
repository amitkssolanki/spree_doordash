RSpec.describe SpreeDoordash::Credential do
  describe 'validations' do
    it 'is valid with developer_id, key_id, signing_secret, and a store' do
      expect(build(:doordash_credential)).to be_valid
    end

    it 'requires a store' do
      credential = build(:doordash_credential, store: nil)
      expect(credential).not_to be_valid
    end

    it 'requires developer_id, key_id, and signing_secret' do
      credential = build(:doordash_credential, developer_id: nil, key_id: nil, signing_secret: nil)
      expect(credential).not_to be_valid
      expect(credential.errors.attribute_names).to include(:developer_id, :key_id, :signing_secret)
    end

    it 'is unique per store' do
      create(:doordash_credential, store: create(:store))
      dup = build(:doordash_credential, store: SpreeDoordash::Credential.first.store)
      expect(dup).not_to be_valid
    end
  end

  describe '#sandbox?' do
    it 'is true for a sandbox-environment credential' do
      expect(build(:doordash_credential, doordash_environment: 'sandbox')).to be_sandbox
    end

    it 'is false for a production-environment credential' do
      expect(build(:doordash_credential, doordash_environment: 'production')).not_to be_sandbox
    end
  end

  describe 'encryption' do
    it 'encrypts developer_id, key_id, signing_secret, and webhook_basic_auth_token at rest' do
      credential = create(:doordash_credential, key_id: 'plain-key-id')
      raw = ActiveRecord::Base.connection.select_value(
        "SELECT key_id FROM spree_doordash_credentials WHERE id = #{credential.id}"
      )
      expect(raw).not_to eq('plain-key-id')
      expect(credential.reload.key_id).to eq('plain-key-id')
    end
  end
end
