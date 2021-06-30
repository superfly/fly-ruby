module Fly
  module Rails
    class Configuration
      # Environment variable defining in which region the primary database lives, i.e 'ams'
      attr_accessor :primary_region_environment_variable
    end
  end
end
