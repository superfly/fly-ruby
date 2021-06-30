require_relative "environment"

module Fly
  module Rails
    class RegionalDatabase
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
        res = Rack::Response.new(response_body, 409, {"fly-replay" => "region=#{primary_region}"})
        res.finish
      end

      def region_preferred?(request)
        threshold = request.cookies["fly-redirect-threshold"]
        threshold && (threshold.to_i - Time.now.to_i) > 0
      end

      def call(env)
        request = Rack::Request.new(env)

        return respond_with_redirect_to_primary_region if region_preferred?(request)

        begin
          response = @app.call(env)
        rescue ActiveRecord::StatementInvalid => e
          if e.cause.is_a?(PG::ReadOnlySqlTransaction)
            return respond_with_redirect_to_primary_region
          else
            raise e
          end
        end
        # Request was replayed, so set a regional preference for the next 5 seconds
        if request.get_header("Fly-Dispatch-Start")&.scan(/t/)&.count == 2
          response.set_cookie("fly-redirect-threshold", 5.seconds.from_now.to_i)
        end

        response
      end
    end
  end
end
