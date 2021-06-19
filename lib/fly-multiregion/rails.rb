require_relative "capture_readonly"
require_relative "environment"

class Fly::MultiRegion::Railtie < Rails::Railtie
  include Fly::MultiRegion::Environment
  initializer("fly.multiregion") do |app|
    warn and return unless eligible_for_redirect?
    app.config.middleware.use Fly::MultiRegion::CaptureReadOnly
  end

  def warn
    puts "Warning: DATABASE_URL, FLY_PRIMARY_REGION and FLY_REGION must be present to implement the fly-multiregion middleware"
  end
end
