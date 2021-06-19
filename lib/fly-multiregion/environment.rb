module Fly
  module MultiRegion
    module Environment
      def database_url
        ENV["DATABASE_URL"]
      end

      def primary_region
        ENV["FLY_PRIMARY_REGION"]
      end

      def current_region
        ENV["FLY_REGION"]
      end

      def eligible_for_redirect?
        database_url && primary_region && current_region
      end
    end
  end
end