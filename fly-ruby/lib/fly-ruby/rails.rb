require_relative "regional_database"

class Fly::Rails::Railtie < Rails::Railtie
  initializer("fly.regional_database") do |app|
    if Fly.configuration.eligible_for_activation?
      app.config.middleware.use Fly::Rails::RegionalDatabase
    elsif !ENV["TESTING"]
      puts "Warning: DATABASE_URL, PRIMARY_REGION and FLY_REGION must be set to activate the fly-rails middleware. Middleware not loaded."
    end
  end
end
