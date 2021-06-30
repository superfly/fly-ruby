require_relative "fly-rails/rails"
require_relative "fly-rails/configuration"

def init(&block)
  config = Configuration.new
  yield(config) if block
end
