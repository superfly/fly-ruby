module Fly
  module Rails
    module Environment
      def database_url
        ENV["DATABASE_URL"]
      end

      def primary_region
        ENV["PRIMARY_REGION"]
      end

      def current_region
        ENV["FLY_REGION"]
      end

      def eligible_for_redirect?
        database_url && primary_region && current_region
      end

      def debug(msg)
        puts msg if ENV["DEBUG_FLY"]
      end
    end
  end
end
