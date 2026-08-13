module SpreeDoordash
  # Maps a DoorDash Store (their own Business/Store hierarchy — a Business
  # owns multiple physical pickup Stores) 1:1 to a Spree::StockLocation.
  # Structural twin of SpreeSquare::LocationMapping — see that class's own
  # comment for why restaurant branches map onto Spree's existing
  # multi-warehouse StockLocation model rather than a bespoke concept.
  class LocationMapping < Spree.base_class
    self.table_name = 'spree_doordash_location_mappings'

    belongs_to :stock_location, class_name: 'Spree::StockLocation'
    belongs_to :store, class_name: 'Spree::Store'

    validates :doordash_store_id, presence: true, uniqueness: true
    validates :stock_location, presence: true, uniqueness: true
  end
end
