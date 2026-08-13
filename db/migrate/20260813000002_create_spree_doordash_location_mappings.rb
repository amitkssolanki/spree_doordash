class CreateSpreeDoordashLocationMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_doordash_location_mappings do |t|
      t.references :stock_location, null: false, foreign_key: { to_table: :spree_stock_locations }, index: { unique: true }
      t.references :store, null: false, foreign_key: { to_table: :spree_stores }

      # DoorDash's own Business/Store hierarchy — a Business owns multiple
      # Stores, each a physical pickup location. Structural twin of
      # SpreeSquare::LocationMapping (one row per external-system concept,
      # unique index on the external id, no shared/polymorphic mapping
      # table), except this one carries spree_store_id from day one —
      # SpreeSquare's own mapping tables don't, which its README flags as a
      # gap before real multi-store use. Cheap to not repeat here.
      t.string :doordash_store_id, null: false
      t.string :doordash_business_id

      t.timestamps
    end

    add_index :spree_doordash_location_mappings, :doordash_store_id, unique: true
  end
end
