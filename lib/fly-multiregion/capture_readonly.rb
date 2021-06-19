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

      def redirect_to_primary_region!
        response.headers["fly-replay"] = "region=#{primary_region}"
        puts "Replaying request in #{primary_region}"
        render plain: "retry in region #{primary_regionGe}", status: 409
      end

      def call(env)
        response = @app.call(env)
      rescue ActiveRecord::StatementInvalid => e
        if e.cause.is_a?(PG::ReadOnlySqlTransaction)
          redirect_to_primary_region!
        else
          raise e
        end
      end
    end
  end
end