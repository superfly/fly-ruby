require "rack/test"
require "minitest/autorun"
require_relative "../lib/fly-ruby"

ENV["TESTING"] = "1"

class TestFlyRuby < Minitest::Test
  include Rack::Test::Methods

  def setup
    ENV['DATABASE_URL'] = 'postgres://localhost:5432'
    Fly.configure do |config|
      config.primary_region = "iad"
      config.current_region = "ams"
    end
  end

  def app
    app = lambda { |env| [200, {"Content-Type" => "text/plain"}, ["OK"]] }
    Fly::RegionalDatabase.new(app)
  end

  def test_get_request_wont_replay_or_set_cookies
    get "/"
    assert last_response.ok?
    refute last_response.cookies[Fly.configuration.replay_threshold_cookie]
  end

  def test_post_request_will_replay_on_secondary_region
    post "/"
    assert_replayed
  end

  def test_replayed_request_will_send_next_get_request_to_primary
    simulate_replayed_post
    assert last_response.ok?
    assert last_response.cookies[Fly.configuration.replay_threshold_cookie].value.first.to_i > Time.now.to_i
    simulate_secondary_get
    assert_replayed
    refute last_response.cookies[Fly.configuration.replay_threshold_cookie]
  end

  def simulate_replayed_post
    Fly.configuration.current_region = Fly.configuration.primary_region
    header Fly.configuration.fly_dispatch_header, "t=2000, t=3000"
    post "/"
  end

  def simulate_secondary_get
    Fly.configuration.current_region = "ams"
    header Fly.configuration.fly_dispatch_header, "t=2000"
    get "/"
  end

  def assert_replayed
    assert_equal 409, last_response.status
    assert_equal "region=iad", last_response.headers["fly-replay"]
  end
end
