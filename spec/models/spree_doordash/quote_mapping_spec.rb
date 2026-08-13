RSpec.describe SpreeDoordash::QuoteMapping do
  it 'is valid with an order and external_delivery_id' do
    expect(build(:doordash_quote_mapping)).to be_valid
  end

  it 'is unique per order' do
    mapping = create(:doordash_quote_mapping)
    dup = build(:doordash_quote_mapping, order: mapping.order)
    expect(dup).not_to be_valid
  end

  describe '#expired?' do
    it 'is true once quote_expires_at has passed' do
      mapping = build(:doordash_quote_mapping, quote_expires_at: 1.minute.ago)
      expect(mapping).to be_expired
    end

    it 'is false comfortably before expiry' do
      mapping = build(:doordash_quote_mapping, quote_expires_at: 4.minutes.from_now)
      expect(mapping).not_to be_expired
    end

    it 'is true with no quote_expires_at recorded' do
      mapping = build(:doordash_quote_mapping, quote_expires_at: nil)
      expect(mapping).to be_expired
    end
  end
end
