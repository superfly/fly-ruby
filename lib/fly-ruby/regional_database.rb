# frozen_string_literal: true

require 'rake'

module Fly
  # Note that using instance variables in Rack middleware is considered a poor practice in
  # multithreaded environments. Instead of using dirty tricks like using Object#dup,
  # values are passed to methods.

  module RegionalDatabase
    # Stop the current request and ask for it to be replayed in the primary region.
    # Pass one of three states to the target region, to determine how to handle the request:
    #
    # Possible states: captured_write, http_method, threshold
    # captured_write: A write was rejected by the database
    # http_method: A non-idempotent HTTP method was replayed before hitting the application
    # threshold: A recent write set a threshold during which all requests are replayed

    def self.replay_in_primary_region!(state:)
      res = Rack::Response.new(
        "",
        409,
        {"Fly-Replay" => "region=#{Fly.configuration.primary_region};state=#{state}"}
      )
      res.finish
    end

    class DbExceptionHandlerMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        exceptions = Fly.configuration.replayable_exception_classes
        @app.call(env)
      rescue *exceptions, ActiveRecord::RecordInvalid => e
        if exceptions.any? {|ex| e.is_a?(ex) } || exceptions.any? { e&.cause&.is_a?(e) }
          RegionalDatabase.replay_in_primary_region!(state: "captured_write")
        else
          raise e
        end
      end
    end

    class ReplayableRequestMiddleware
      def initialize(app)
        @app = app
      end

      def within_replay_threshold?(threshold)
        threshold && (threshold.to_i - Time.now.to_i) > 0
      end

      def replayable_http_method?(http_method)
        Fly.configuration.replay_http_methods.include?(http_method)
      end

      def replay_request_state(header_value)
        header_value&.slice(/(?:^|;)state=([^;]*)/, 1)
      end

      def call(env)
        request = Rack::Request.new(env)

        # Does this request satisfiy a condition for replaying in the primary region?
        #
        # 1. Its HTTP method matches those configured for automatic replay
        # 2. It arrived before the threshold defined by the last write request.
        #    This threshold helps avoid the same client from missing its own
        #    write due to replication lag.

        if Fly.configuration.in_secondary_region?
          if replayable_http_method?(request.request_method)
            return RegionalDatabase.replay_in_primary_region!(state: "http_method")
          elsif within_replay_threshold?(request.cookies[Fly.configuration.replay_threshold_cookie])
            return RegionalDatabase.replay_in_primary_region!(state: "threshold")
          end
        end

        status, headers, body = @app.call(env)

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
end
