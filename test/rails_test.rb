require "rack/test"
require "minitest/autorun"
require "bundler/setup"
require "climate_control"
require "minitest/around/unit"
require "active_support/testing/isolation"

require_relative "test_rails_app/app"

POSTGRES_HOST = ENV["DATABASE_HOST"] || "localhost"

class TestFlyRails < Minitest::Test
  include ActiveSupport::Testing::Isolation
  include Rack::Test::Methods

  attr_reader :app

  def setup
    ENV["DATABASE_URL"] = "postgres://#{POSTGRES_HOST}:5432/fly_ruby_test"
    ENV["PRIMARY_REGION"] = "iad"
    ENV["FLY_REGION"] = "ams"
    Fly.configuration = nil
    @app = make_basic_app
  end

  def test_middleware_inserted_with_required_env_vars
    index_of_executor = @app.middleware.find_index { |m| m == ActionDispatch::Executor }
    assert_equal index_of_executor + 1, @app.middleware.find_index(Fly::Headers)
    assert_equal index_of_executor + 2, @app.middleware.find_index(Fly::RegionalDatabase::ReplayableRequestMiddleware)
    assert_equal @app.middleware.size - 1, @app.middleware.find_index(Fly::RegionalDatabase::DbExceptionHandlerMiddleware)
  end

  def test_database_configuration_is_overridden
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "top1.nearest.of.#{POSTGRES_HOST}.internal", config[:host]
    assert_equal 5433, config[:port]
  end

  def test_database_configuration_is_overridden_when_connection_reestablished
    ActiveRecord::Base.establish_connection({ url: "postgres://#{POSTGRES_HOST}:5432/fly_ruby_test" })
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal POSTGRES_HOST, config[:host]
    assert_equal 5432, config[:port]

    ActiveRecord::Base.establish_connection
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "top1.nearest.of.#{POSTGRES_HOST}.internal", config[:host]
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

class TestFlyRailsPrimary < Minitest::Test
  include ActiveSupport::Testing::Isolation
  include Rack::Test::Methods

  attr_reader :app

  def setup
    ENV["DATABASE_URL"] = "postgres://#{POSTGRES_HOST}:5432/fly_ruby_test"
    ENV["PRIMARY_REGION"] = "iad"
    ENV["FLY_REGION"] = "iad"
    Fly.configuration = nil
    @app = make_basic_app
  end

  def test_database_configuration_is_overridden
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "iad.#{POSTGRES_HOST}.internal", config[:host]
  end

  def test_database_configuration_is_overridden_when_connection_reestablished
    ActiveRecord::Base.establish_connection({ url: "postgres://#{POSTGRES_HOST}:5432/fly_ruby_test" })
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal POSTGRES_HOST, config[:host]

    ActiveRecord::Base.establish_connection
    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "iad.#{POSTGRES_HOST}.internal", config[:host]
  end
end

class TestFlyRailsAlternativeEnvironments < Minitest::Test
  include ActiveSupport::Testing::Isolation

  def setup
    Fly.configuration = nil
  end

  def test_middleware_skipped_without_required_env_vars
    ENV["PRIMARY_REGION"] = nil

    assert_output %r/middleware not loaded/i do
      make_basic_app
    end
    refute Rails.application.middleware.find_index(Fly::RegionalDatabase)
  end

  def test_database_connection_not_hijacked_when_using_sqlite
    ENV["DATABASE_URL"] = "sqlite3://foo"
    ENV["PRIMARY_REGION"] = "iad"
    ENV["FLY_REGION"] = "ams"
    make_basic_app

    config = ActiveRecord::Base.connection_db_config.configuration_hash
    assert_equal "foo", config[:host]
    assert_nil config[:port]
  end
end
