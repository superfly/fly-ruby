require "rack/test"
require "minitest/autorun"
require_relative "../lib/fly-ruby"

ENV["TESTING"] = "1"

class ConfigurationTest < Minitest::Test
  def setup
    ENV["REDIS_URL"] = "redis://redis.internal:6379"
    ENV["DATABASE_URL"] = "postgresql://db.internal:6379"
    ENV["FLY_REGION"] = "iad"
    @configuration = Fly::Configuration.new
  end

  def test_regional_redis_config
    assert_equal "redis://iad.redis.internal:6379", @configuration.regional_redis_url
    assert_equal "iad.redis.internal", @configuration.regional_redis_host
  end

  def test_regional_database_config
    assert_equal "postgresql://iad.db.internal:6379", @configuration.regional_database_url
    assert_equal "iad.db.internal", @configuration.regional_database_host
  end
end
