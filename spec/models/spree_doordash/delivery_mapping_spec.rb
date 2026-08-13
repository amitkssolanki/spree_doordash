RSpec.describe SpreeDoordash::DeliveryMapping do
  describe 'validations' do
    it 'is valid with a real order and a unique external_delivery_id' do
      mapping = build(:doordash_delivery_mapping)
      expect(mapping).to be_valid
    end

    it 'requires an order' do
      mapping = build(:doordash_delivery_mapping, order: nil)
      expect(mapping).not_to be_valid
    end

    it 'is unique per order' do
      order = create(:order)
      create(:doordash_delivery_mapping, order: order)
      dup = build(:doordash_delivery_mapping, order: order)

      expect(dup).not_to be_valid
    end

    it 'requires a unique external_delivery_id' do
      create(:doordash_delivery_mapping, external_delivery_id: 'dup-id')
      dup = build(:doordash_delivery_mapping, external_delivery_id: 'dup-id')

      expect(dup).not_to be_valid
    end
  end

  describe '#mark_failed!' do
    it 'records a truncated error message' do
      mapping = create(:doordash_delivery_mapping)
      mapping.mark_failed!(StandardError.new('boom'))

      expect(mapping.reload.dispatch_error).to eq('boom')
    end
  end
end
