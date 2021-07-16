require_relative '../fly-ruby'

class Fly::Railtie < Rails::Railtie
  def hijack_database_connection
    ActiveSupport::Reloader.to_prepare do
      # If we already have a database connection when this initializer runs,
      # we should reconnect to the region-local database. This may need some additional
      # hooks for forking servers to work correctly.
      if defined?(ActiveRecord)
        config = ActiveRecord::Base.connection_db_config.configuration_hash
        ActiveRecord::Base.establish_connection(config.merge(Fly.configuration.regional_database_config))
      end
    end
  end

  # Set useful headers for debugging
  def set_debug_response_headers
    ActiveSupport::Reloader.to_prepare do
      ApplicationController.send(:after_action) do
        response.headers['Fly-Region'] = ENV['FLY_REGION']
        response.headers['Fly-Database-Host'] = Fly.configuration.regional_database_config["host"]
      end
    end
  end

  initializer("fly.regional_database") do |app|
    set_debug_response_headers if Fly.configuration.web?

    if Fly.configuration.eligible_for_activation?
      # Run the middleware high in the stack, but after static file delivery
      app.config.middleware.insert_after ActionDispatch::Executor, Fly::RegionalDatabase
      hijack_database_connection if Fly.configuration.in_secondary_region?
    elsif Fly.configuration.web?
      puts "Warning: DATABASE_URL, PRIMARY_REGION and FLY_REGION must be set to activate the fly-ruby middleware. Middleware not loaded."
    end
  end
end
