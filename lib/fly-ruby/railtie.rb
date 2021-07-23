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

  initializer("fly.regional_database") do |app|
    # Insert the request middleware high in the stack, but after static file delivery
    app.config.middleware.insert_after ActionDispatch::Executor, Fly::Headers if Fly.configuration.web?

    if Fly.configuration.eligible_for_activation?
      app.config.middleware.insert_after Fly::Headers, Fly::RegionalDatabase::ReplayableRequestMiddleware
      # Insert the database exception handler at the bottom of the stack to take priority over other exception handlers
      app.config.middleware.use Fly::RegionalDatabase::DbExceptionHandlerMiddleware

      if Fly.configuration.in_secondary_region?
        hijack_database_connection
      end
    elsif Fly.configuration.web?
      puts "Warning: DATABASE_URL, PRIMARY_REGION and FLY_REGION must be set to activate the fly-ruby middleware. Middleware not loaded."
    end
  end
end
