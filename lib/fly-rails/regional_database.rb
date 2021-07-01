module Fly
  module Rails
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

      # Override the configured database URL with that of the regional replica
      def replay_in_primary_region!
        res = Rack::Response.new(response_body, 409, {"fly-replay" => "region=#{Fly.configuration.primary_region}"})
        res.finish
      end

      # Check whether this request satisfies any of the following conditions for replaying in the primary region:
      #
      # 1. It arrived before the threshold defined by the last write request. This threshold
      #    helps avoid the same client from missing its own write due to replication lag,
      #    like when a user updates a todo list via XHR
      #
      # 2. Its HTTP method matches those configured for automatic replay (post/patch/put/delete by default).
      #    This approach should avoid potentially slow code execution - before_actions or other controller code -
      #    happening before a request reaches a database write.
      #
      def primary_region_preferred?(request)
        return true if Fly.configuration.replay_http_methods.include?(request.request_method)

        threshold = request.cookies[Fly.configuration.replay_threshold_cookie]
        threshold && (threshold.to_i - Time.now.to_i) > 0
      end

      def replayed?(request)
        request.get_header("HTTP_#{Fly.configuration.fly_dispatch_header.upcase.gsub("-", "_")}")&.scan(/t/)&.count == 2
      end

      def call(env)
        request = Rack::Request.new(env)

        if !in_primary_region? && primary_region_preferred?(request)
          return replay_in_primary_region!
        end

        begin
          status, headers, body = @app.call(env)
        rescue ActiveRecord::StatementInvalid => e
          if e.cause.is_a?(PG::ReadOnlySqlTransaction)
            return respond_with_redirect_to_primary_region
          else
            raise e
          end
        end
        # Request was replayed, so set a regional preference for the next 5 seconds
        response = Rack::Response.new(body, status, headers)

        if replayed?(request)
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