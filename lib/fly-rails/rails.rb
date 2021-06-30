require_relative "regional_database"
require_relative "environment"

class Fly::Rails::Railtie < Rails::Railtie
  include Fly::Rails::Environment
  initializer("fly.redirect_readonly_queries") do |app|
    warn and return unless eligible_for_redirect?
    app.config.middleware.use Fly::Rails::RegionalDatabase
  end

  def warn
    puts "Warning: DATABASE_URL, FLY_PRIMARY_REGION and FLY_REGION must be present to implement the fly-rails middleware"
  end
end
