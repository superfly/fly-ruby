require_relative "fly-ruby/configuration"
require_relative "fly-ruby/regional_database"
require_relative "fly-ruby/headers"

require "forwardable"

if defined?(::Rails)
  require_relative "fly-ruby/railtie"
end

module Fly
  class << self
    extend Forwardable

    def instance
      @instance ||= Instance.new
    end

    def_delegators :instance, :configuration, :configuration=, :configure
  end

  class Instance
    attr_accessor :configuration

    def initialize
      self.configuration = Fly::Configuration.new
    end

    def configure
      configuration = Fly::Configuration.new
      yield(configuration) if block_given?
      self.configuration = configuration
    end
  end
end
