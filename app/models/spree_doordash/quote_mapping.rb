module SpreeDoordash
  # Tracks the most recent DoorDash Drive quote requested for an order,
  # generated as checkout progresses (see Spree::Calculator::Shipping::
  # DoordashQuote) and consulted again at order.completed to decide whether
  # to accept it as-is or re-quote (see SpreeDoordash::DeliveryDispatcher,
  # M4) — DoorDash quotes are only valid 5 minutes, and checkout can easily
  # take longer than that.
  class QuoteMapping < Spree.base_class
    self.table_name = 'spree_doordash_quote_mappings'

    belongs_to :order, class_name: 'Spree::Order'

    validates :order, presence: true, uniqueness: true
    validates :external_delivery_id, presence: true, uniqueness: true

    def expired?
      quote_expires_at.blank? || quote_expires_at <= Time.current
    end
  end
end
