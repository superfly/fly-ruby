module Fly
  # Note that using instance variables in Rack middleware is considered a poor practice in
  # multithreaded environments. Instead of using dirty tricks like using Object#dup,
  # values are passed to methods.

  class RegionalDatabase
    def initialize(app)
      @app = app
      prefer_regional_database! unless in_primary_region?
    end

    # Overwrite the primary database URL with that of the regional replica
    def prefer_regional_database!
      ENV[Fly.configuration.database_url_env_var] = regional_database_url
    end

    def in_primary_region?
      Fly.configuration.primary_region == Fly.configuration.current_region
    end

    def regional_database_url
      uri = URI.parse(Fly.configuration.database_url)
      uri.hostname = "#{Fly.configuration.current_region}.#{uri.hostname}"
      uri.port = 5433
      uri.to_s
    end

    def response_body
      "<html>Replaying request in #{Fly.configuration.primary_region}</html>"
    end

    # Stop the current request and ask for it to be replayed in the primary region.
    # Pass one of three reasons to the target region, to determine how to handle the request:
    #
    # Possible reasons: captured_write, http_method, threshold
    # captured_write: A write was rejected by the database
    # http_method: A non-idempotent HTTP method was replayed before hitting the application
    # threshold: A recent write set a threshold during which all requests are replayed
    #
    def replay_in_primary_region!(reason:)
      res = Rack::Response.new(
        response_body,
        409,
        {"fly-replay" => "region=#{Fly.configuration.primary_region}; reason=#{reason}"}
      )
      res.finish
    end

    def within_replay_threshold?(threshold)
      threshold && (threshold.to_i - Time.now.to_i) > 0
    end

    def replayable_http_method?(http_method)
      Fly.configuration.replay_http_methods.include?(http_method)
    end

    def replay_request_reason(header_value)
      header_value&.scan(/(.*?)=(.*?)($|;)/)&.detect { |v| v[0] == "reason" }&.at(1)
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

      if !in_primary_region?
        if replayable_http_method?(request.request_method)
          return replay_in_primary_region!(reason: "http_method")
        elsif within_replay_threshold?(request.cookies[Fly.configuration.replay_threshold_cookie])
          return replay_in_primary_region!(reason: "threshold")
        end
      end

      begin
        status, headers, body = @app.call(env)
      rescue ActiveRecord::reasonmentInvalid => e
        if e.cause.is_a?(PG::ReadOnlySqlTransaction)
          return replay_in_primary_region!(reason: "captured_write")
        else
          raise e
        end
      end

      response = Rack::Response.new(body, status, headers)
      replay_reason = replay_request_reason(request.get_header("HTTP_FLY_REPLAY_SRC"))

      # Request was replayed, but not by a threshold
      if replay_reason && replay_reason != "threshold"
        response.set_cookie(
          Fly.configuration.replay_threshold_cookie,
          Time.now.to_i + Fly.configuration.replay_threshold_in_seconds
        )
      end

      response.finish
    end
  end
end
