RSpec.describe SpreeDoordash::LocationMapping do
  it 'is valid with a stock location, store, and doordash_store_id' do
    expect(build(:doordash_location_mapping)).to be_valid
  end

  it 'is unique per stock location' do
    location = create(:doordash_location_mapping)
    dup = build(:doordash_location_mapping, stock_location: location.stock_location)
    expect(dup).not_to be_valid
  end

  it 'is unique per doordash_store_id' do
    location = create(:doordash_location_mapping)
    dup = build(:doordash_location_mapping, doordash_store_id: location.doordash_store_id)
    expect(dup).not_to be_valid
  end
end
