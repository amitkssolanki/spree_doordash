require 'spree'
require 'spree_doordash/engine'
require 'spree_doordash/version'
require 'spree_doordash/configuration'

module SpreeDoordash
  mattr_accessor :queue

  def self.queue
    @@queue ||= Spree.queues.default
  end
end
