require 'rake'

module Fly
  # Note that using instance variables in Rack middleware is considered a poor practice in
  # multithreaded environments. Instead of using dirty tricks like using Object#dup,
  # values are passed to methods.

  class RegionalDatabase
    def initialize(app)
      @app = app
    end

    def response_body
      "<html>Replaying request in #{Fly.configuration.primary_region}</html>"
    end

    # Stop the current request and ask for it to be replayed in the primary region.
    # Pass one of three states to the target region, to determine how to handle the request:
    #
    # Possible states: captured_write, http_method, threshold
    # captured_write: A write was rejected by the database
    # http_method: A non-idempotent HTTP method was replayed before hitting the application
    # threshold: A recent write set a threshold during which all requests are replayed
    #
    def replay_in_primary_region!(state:)
      res = Rack::Response.new(
        "",
        409,
        {"Fly-Replay" => "region=#{Fly.configuration.primary_region};state=#{state}"}
      )
      res.finish
    end

    def within_replay_threshold?(threshold)
      threshold && (threshold.to_i - Time.now.to_i) > 0
    end

    def replayable_http_method?(http_method)
      Fly.configuration.replay_http_methods.include?(http_method)
    end

    def replay_request_state(header_value)
      header_value&.scan(/(.*?)=(.*?)($|;)/)&.detect { |v| v[0] == "state" }&.at(1)
    end

    def call(env)
      request = Rack::Request.new(env)

    # Check whether this request satisfies any of the following conditions for replaying in the primary region:
    #
    # 1. Its HTTP method matches those configured for automatic replay (post/patch/put/delete by default).
    #    This approach should avoid potentially slow code execution - before_actions or other controller code -
    #    happening before a request reaches a database write.
    # 2. It arrived before the threshold defined by the last write request. This threshold
    #    helps avoid the same client from missing its own write due to replication lag,
    #    like when a user adds to a todo list via XHR
      if Fly.configuration.in_secondary_region?
        if replayable_http_method?(request.request_method)
          return replay_in_primary_region!(state: "http_method")
        elsif within_replay_threshold?(request.cookies[Fly.configuration.replay_threshold_cookie])
          return replay_in_primary_region!(state: "threshold")
        end
      end

      begin
        status, headers, body = @app.call(env)
      rescue ActiveRecord::StatementInvalid => e
        if e.cause.is_a?(PG::ReadOnlySqlTransaction)
          return replay_in_primary_region!(state: "captured_write")
        else
          raise e
        end
      end

      response = Rack::Response.new(body, status, headers)
      replay_state = replay_request_state(request.get_header("HTTP_FLY_REPLAY_SRC"))

      # Request was replayed, but not by a threshold, so set a threshold within which
      # all requests should be replayed to the primary region
      if replay_state && replay_state != "threshold"
        response.set_cookie(
          Fly.configuration.replay_threshold_cookie,
          Time.now.to_i + Fly.configuration.replay_threshold_in_seconds
        )
      end

      response.finish
    end
  end
end
