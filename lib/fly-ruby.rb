# frozen_string_literal: true

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
    attr_writer :configuration

    def configuration
      @configuration ||= Fly::Configuration.new
    end

    def configure(&block)
      configuration.tap(&block)
    end
  end
end
