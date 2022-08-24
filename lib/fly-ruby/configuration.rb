# frozen_string_literal: true

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
    attr_accessor :redis_url_env_var

    # Cookie written and read by this middleware storing a UNIX timestamp.
    # Requests arriving before this timestamp will be replayed in the primary region.
    attr_accessor :replay_threshold_cookie

    # How long, in seconds, should all requests from the same client be replayed in the
    # primary region after a successful write replay
    attr_accessor :replay_threshold_in_seconds

    attr_accessor :database_url
    attr_accessor :redis_url

    # An array of string representations of exceptions that should trigger a replay
    attr_accessor :replayable_exceptions

    def initialize
      self.primary_region = ENV["PRIMARY_REGION"]
      self.current_region = ENV["FLY_REGION"]
      self.replay_http_methods = ["POST", "PUT", "PATCH", "DELETE"]
      self.database_url_env_var = "DATABASE_URL"
      self.redis_url_env_var = "REDIS_URL"
      self.database_host_env_var = "DATABASE_HOST"
      self.database_port_env_var = "DATABASE_PORT"
      self.replay_threshold_cookie = "fly-replay-threshold"
      self.replay_threshold_in_seconds = 5
      self.database_url = ENV[database_url_env_var]
      self.redis_url = ENV[redis_url_env_var]
      self.replayable_exceptions = ["SQLite3::CantOpenException", "PG::ReadOnlySqlTransaction"]
    end

    def replayable_exception_classes
      @replayable_exception_classes ||= replayable_exceptions.collect {|ex| module_exists?(ex) }.compact
      @replayable_exception_classes
    end

    def module_exists?(module_name)
      mod = Module.const_get(module_name)
      return mod
    rescue NameError
      nil
    end

    def database_uri
      @database_uri ||= URI.parse(database_url)
    end

    def database_app_name
      database_uri.hostname.split(".")[-2] || database_uri.hostname
    end

    def database_domain
      "#{database_app_name}.internal"
    end

    def primary_database_url
      uri = database_uri.dup
      uri.host = "#{primary_region}.#{database_domain}"
      uri.port = secondary_database_port
      uri.to_s
    end

    def secondary_database_url
      uri = database_uri.dup
      uri.host = "top1.nearest.of.#{database_domain}"
      uri.port = secondary_database_port
      uri.to_s
    end

    def secondary_database_port
      port = if in_secondary_region?
        case database_uri.scheme
        when "postgres"
          5433
        end
      end

      port || database_uri.port
    end

    def redis_uri
      @redis_uri ||= URI.parse(redis_url)
      @redis_uri
    end

    def regional_redis_host
      "#{current_region}.#{redis_uri.hostname}"
    end

    def regional_redis_url
      uri = redis_uri.dup
      uri.host = regional_redis_host
      uri.to_s
    end

    def eligible_for_activation?
      database_url && primary_region && current_region && web?
    end

    def hijack_database_connection!
      # Don't reset the database URL for on-disk sqlite
      return if database_uri.scheme.start_with?("sqlite") || database_uri.host !~ /(internal|localhost)/
      ENV["DATABASE_URL"] = in_secondary_region? ? secondary_database_url : primary_database_url
    end

    def in_secondary_region?
      primary_region && primary_region != current_region
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
