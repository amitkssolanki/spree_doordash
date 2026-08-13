module SpreeDoordash
  class BaseJob < Spree::BaseJob
    queue_as SpreeDoordash.queue
  end
end
