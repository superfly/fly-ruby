require "rack/test"
require "minitest/autorun"
require "bundler/setup"
require_relative "test_rails_app/app"

ENV['PRIMARY_REGION'] = 'ams'
ENV['FLY_REGION'] = 'iad'
ENV['DATABASE_URL'] = 'postgres://test'

class TestFlyRails < Minitest::Test
  include Rack::Test::Methods

  def setup
    @app = make_basic_app
  end

  def test_middleware_skipped_without_required_env_vars
    refute middleware_index
  end

  def test_middleware_inserted_with_required_env_vars
    ENV['PRIMARY_REGION'] = nil
    @app = make_basic_app
    index_of_executor = @app.middleware.find_index { |m| m == ActionDispatch::Executor }
    assert_equal index_of_executor + 1, middleware_index
  end

  def middleware_index
    @app.middleware.find_index(Fly::RegionalDatabase)
  end
end