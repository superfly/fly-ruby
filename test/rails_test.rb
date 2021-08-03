require "rack/test"
require "minitest/autorun"
require "bundler/setup"
require "climate_control"
require "minitest/around/unit"

require_relative "test_rails_app/app"

POSTGRES_HOST = ENV["DATABASE_HOST"] || "localhost"

class TestFlyRails < Minitest::Test
  include Rack::Test::Methods

  attr_reader :app

  def setup
    ENV["DATABASE_URL"] = "postgres://#{POSTGRES_HOST}:5432/fly_ruby_test"
    Fly.configuration.current_region = "ams"
    Fly.configuration.primary_region = "iad"
    ENV["PRIMARY_REGION"] = "iad"
    ENV["FLY_REGION"] = "ams"
    @app = make_basic_app
  end

  def test_middleware_inserted_with_required_env_vars
    index_of_executor = @app.middleware.find_index { |m| m == ActionDispatch::Executor }
    assert_equal index_of_executor + 1, @app.middleware.find_index(Fly::Headers)
    assert_equal index_of_executor + 2, @app.middleware.find_index(Fly::RegionalDatabase::ReplayableRequestMiddleware)
    assert_equal @app.middleware.size - 1, @app.middleware.find_index(Fly::RegionalDatabase::DbExceptionHandlerMiddleware)
  end

  def test_database_connection_is_overloaded
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "ams.#{POSTGRES_HOST}", config[:host]
    assert_equal 5433, config[:port]
  end

  def test_debug_headers_are_appended_to_responses
    get "/"
    assert_equal "ams", last_response.headers["Fly-Region"]
  end

  def test_post_gets_replayed
    post "/world"
    assert last_response.headers['Fly-Replay']
  end

  def test_database_write_exception_gets_replayed
    get "/exception"
    assert last_response.headers["Fly-Replay"] =~ /captured_write/
  end
end

class TestBadEnv < Minitest::Test
  def setup
    Fly.configuration.primary_region = nil
  end

  def test_middleware_skipped_without_required_env_vars
    make_basic_app
    refute Rails.application.middleware.find_index(Fly::RegionalDatabase)
  end
end