require_relative "environment"

module Fly
  module Rails
    class CaptureReadOnly
      include Environment

      def initialize(app)
        @app = app
        prefer_regional_database
      end

      def prefer_regional_database
        return if primary_region == current_region
        ENV["DATABASE_URL"] = regional_database_url
      end

      def regional_database_url
        uri = URI.parse(database_url)
        uri.hostname = "#{current_region}.#{uri.hostname}"
        uri.port = 5433
        uri.to_s
      end

      def response_body
        "<html>Replaying request in #{primary_region}</html>"
      end

      def respond_with_redirect_to_primary_region
        [409, {"fly-replay" => "region=#{primary_region}"}, [response_body]]
      end

      def inject_regional_preference_in_rack_session(env)
        # Trick to force the session to load, in case it's not been used yet in the application
        env["rack.session"].delete(:force_session_load)
        env["rack.session"]["fly_redirect_threshold"] = 2.seconds.from_now.to_i
      end

      def region_preferred?(env)
        threshold = env["rack.session"]["fly_redirect_threshold"]
        return true if threshold && (threshold - Time.now.to_i) > 0
        env["rack.session"]["fly_redirect_threshold"] = nil
      end

      def call(env)
        return respond_with_redirect_to_primary_region if region_preferred?(env)

        begin
          response = @app.call(env)
        rescue ActiveRecord::StatementInvalid => e
          if e.cause.is_a?(PG::ReadOnlySqlTransaction)
            inject_regional_preference_in_rack_session(env)
            return respond_with_redirect_to_primary_region
          else
            raise e
          end
        end

        response
      end
    end
  end
end
