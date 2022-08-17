# frozen_string_literal: true

class Fly::Railtie < Rails::Railtie
  initializer("fly.regional_database", before: "active_record.initialize_database") do |app|
    # Insert the request middleware high in the stack, but after static file delivery
    app.config.middleware.insert_after ActionDispatch::Executor, Fly::Headers if Fly.configuration.web?

    if Fly.configuration.eligible_for_activation?
      app.config.middleware.insert_after Fly::Headers, Fly::RegionalDatabase::ReplayableRequestMiddleware
      # Insert the database exception handler at the bottom of the stack to take priority over other exception handlers
      app.config.middleware.use Fly::RegionalDatabase::DbExceptionHandlerMiddleware

      if Fly.configuration.hijack_database_connection?
        ENV["DATABASE_URL"] = Fly.configuration.regional_database_url
      end
    elsif Fly.configuration.web?
      puts "Warning: DATABASE_URL, PRIMARY_REGION and FLY_REGION must be set to activate the fly-ruby middleware. Middleware not loaded."
    end
  end
end
