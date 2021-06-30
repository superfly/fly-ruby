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

      def respond_with_redirect_to_primary_region(env)
        res = Rack::Response.new(response_body, 409, {"fly-replay" => "region=#{primary_region}"})
        res.set_cookie("fly-redirect-threshold", 2.seconds.from_now.to_i)
        res.finish
      end

      def region_preferred?(env)
        request = Rack::Request.new(env)
        threshold = request.cookies["fly-redirect-threshold"]
        threshold && (threshold.to_i - Time.now.to_i) > 0
      end

      def call(env)
        return respond_with_redirect_to_primary_region(env) if region_preferred?(env)

        begin
          response = @app.call(env)
        rescue ActiveRecord::StatementInvalid => e
          if e.cause.is_a?(PG::ReadOnlySqlTransaction)
            return respond_with_redirect_to_primary_region(env)
          else
            raise e
          end
        end

        response
      end
    end
  end
end
