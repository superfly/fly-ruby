class Fly::Railtie < Rails::Railtie
  initializer("fly.regional_database") do |app|
    if Fly.configuration.eligible_for_activation?
      # Run the middleware high in the stack, but after static file delivery
      app.config.middleware.insert_after ActionDispatch::Executor, Fly::RegionalDatabase

      # If we already have a database connection when this initializer runs,
      # we should reconnect to the region-local database. This may need some additional
      # hooks for forking servers to work correctly.
      if defined(ActiveRecord) && ActiveRecord::Base.connected?
        config = Rails.application.config.database_configuration[Rails.env]
        ActiveRecord::Base.connect_to(config)
      end
    elsif Fly.configuration.web?
      puts "Warning: DATABASE_URL, PRIMARY_REGION and FLY_REGION must be set to activate the fly-ruby middleware. Middleware not loaded."
    end
  end
end
