module Fly
  class Configuration
    # Set the region where this instance of the application is deployed
    attr_accessor :current_region

    # Set the region where the primary database lives, i.e "ams"
    attr_accessor :primary_region

    # Automatically replay these HTTP methods in the primary region
    attr_accessor :replay_http_methods

    # Environment variables related to the database connection.
    # These get by this middleware in secondary regions, so they must be interpolated
    # rather than defined directly in the configuration.
    attr_accessor :database_url_env_var
    attr_accessor :database_host_env_var
    attr_accessor :database_port_env_var

    # Cookie written and read by this middleware storing a UNIX timestamp.
    # Requests arriving before this timestamp will be replayed in the primary region.
    attr_accessor :replay_threshold_cookie

    # How long, in seconds, should all requests from the same client be replayed in the
    # primary region after a successful write replay
    attr_accessor :replay_threshold_in_seconds

    def initialize
      self.primary_region = ENV["PRIMARY_REGION"]
      self.current_region = ENV["FLY_REGION"]
      self.replay_http_methods = ["POST", "PUT", "PATCH", "DELETE"]
      self.database_url_env_var = "DATABASE_URL"
      self.database_host_env_var = "DATABASE_HOST"
      self.database_port_env_var = "DATABASE_PORT"
      self.replay_threshold_cookie = "fly-replay-threshold"
      self.replay_threshold_in_seconds = 5
    end

    def database_url
      ENV[database_url_env_var]
    end

    def regional_database_uri
      @uri ||= URI.parse(database_url)
      @uri
    end

    # Rails-compatible database configuration
    def regional_database_config
      {
        "host" => "#{current_region}.#{regional_database_uri.hostname}",
        "port" => 5433,
        "adapter" => "postgresql"
      }
    end

    def eligible_for_activation?
      database_url && primary_region && current_region && web?
    end

    # Is the current process a Rails console?
    def console?
      defined?(::Rails::Console) && $stdout.isatty && $stdin.isatty
    end

    # Is the current process a rake task?
    def rake_task?
      defined?(::Rake) && !Rake.application.top_level_tasks.empty?
    end

    def web?
      !console? && !rake_task?
    end
  end
end
