require "rack/test"
require "minitest/autorun"
require_relative "../lib/fly-ruby"

ENV["TESTING"] = "1"

class RegionalDatabaseTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    ENV['DATABASE_URL'] = 'postgres://localhost:5432'
    Fly.configuration = nil
    Fly.configure do |config|
      config.primary_region = "iad"
      config.current_region = "ams"
    end
  end

  def app
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ["OK"]] }
    Fly::RegionalDatabase::ReplayableRequestMiddleware.new(app)
  end

  def test_get_request_wont_replay_or_set_cookies
    get "/"
    assert last_response.ok?
    refute last_response.cookies[Fly.configuration.replay_threshold_cookie]
  end

  def test_post_request_will_replay_on_secondary_region
    post "/"
    assert_replayed("http_method")
  end

  def test_replayed_request_will_send_next_get_request_to_primary
    simulate_replayed_post("captured_write")
    assert last_response.ok?
    assert last_response.cookies[Fly.configuration.replay_threshold_cookie].value.first.to_i > Time.now.to_i
    simulate_secondary_get
    assert_replayed("threshold")
    refute last_response.cookies[Fly.configuration.replay_threshold_cookie]
  end

  def test_threshold_replayed_request_will_not_reset_threshold_cookie
    simulate_replayed_post("captured_write")
    simulate_secondary_get
    simulate_replayed_post("threshold")
    refute last_response.cookies[Fly.configuration.replay_threshold_cookie]
  end

  def simulate_replayed_post(state)
    Fly.configuration.current_region = Fly.configuration.primary_region
    header "Fly-Replay-Src", "state=#{state}"
    post "/"
  end

  def simulate_secondary_get
    Fly.configuration.current_region = "ams"
    get "/"
  end

  def assert_replayed(state)
    assert_equal 409, last_response.status
    assert_equal "region=iad;state=#{state}", last_response.headers["Fly-Replay"]
  end
end
