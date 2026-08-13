RSpec.describe SpreeDoordash::WebhookVerifier do
  describe '.valid?' do
    it 'is true when the Authorization header exactly matches the configured token' do
      expect(
        described_class.valid?(authorization_header: 'Basic dGVzdDp0ZXN0', expected_token: 'Basic dGVzdDp0ZXN0')
      ).to be true
    end

    it 'is false when the header does not match' do
      expect(
        described_class.valid?(authorization_header: 'Basic wrong', expected_token: 'Basic dGVzdDp0ZXN0')
      ).to be false
    end

    it 'is false when the header is missing' do
      expect(
        described_class.valid?(authorization_header: nil, expected_token: 'Basic dGVzdDp0ZXN0')
      ).to be false
    end

    it 'is false when there is no configured token to compare against (no credential connected)' do
      expect(
        described_class.valid?(authorization_header: 'Basic dGVzdDp0ZXN0', expected_token: nil)
      ).to be false
    end
  end
end
