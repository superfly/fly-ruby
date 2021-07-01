require_relative "regional_database"

class Fly::Rails::Railtie < Rails::Railtie
  initializer("fly.regional_database") do |app|
    warn and return unless eligible_for_redirect?
    app.config.middleware.use Fly::Rails::RegionalDatabase
  end

  def eligible_for_redirect?
    Fly.configuration.database_url && Fly.configuration.primary_region && Fly.configuration.current_region
  end

  def warn
    puts "Warning: DATABASE_URL, FLY_PRIMARY_REGION and FLY_REGION must be present to implement the fly-rails middleware. Middleware not loaded."
  end
end
