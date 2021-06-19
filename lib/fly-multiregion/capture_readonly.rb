require_relative "environment"

module Fly
  module MultiRegion
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

      def response_with_redirect_to_primary_region
        [409, {"fly-replay" => "region=#{primary_region}"}, [response_body]]
      end

      def call(env)
        begin
          response = @app.call(env)
        rescue ActiveRecord::StatementInvalid => e
          if e.cause.is_a?(PG::ReadOnlySqlTransaction)
            return response_with_redirect_to_primary_region
          else
            raise e
          end
        end

        response
      end
    end
  end
end
