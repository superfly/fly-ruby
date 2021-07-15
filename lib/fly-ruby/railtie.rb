require_relative '../fly-ruby'

class Fly::Railtie < Rails::Railtie
  initializer("fly.regional_database") do |app|
    if Fly.configuration.eligible_for_activation?
      # Run the middleware high in the stack, but after static file delivery
      app.config.middleware.insert_after ActionDispatch::Executor, Fly::RegionalDatabase

      ActiveSupport::Reloader.to_prepare do
        # If we already have a database connection when this initializer runs,
        # we should reconnect to the region-local database. This may need some additional
        # hooks for forking servers to work correctly.
        if defined?(ActiveRecord) && ActiveRecord::Base.connected?
          config = ActiveRecord::Base.connection_db_config.configuration_hash
          ActiveRecord::Base.establish_connection(config.merge(Fly.configuration.regional_database_config))
        end

        # Set useful headers for debugging
        ::ApplicationController.send(:after_action) do
          response.headers['Fly-Region'] = ENV['FLY_REGION']
          response.headers['Fly-Database-Host'] = Fly.configuration.regional_database_config["host"]
        end
      end

    elsif Fly.configuration.web?
      puts "Warning: DATABASE_URL, PRIMARY_REGION and FLY_REGION must be set to activate the fly-ruby middleware. Middleware not loaded."
    end
  end
end
