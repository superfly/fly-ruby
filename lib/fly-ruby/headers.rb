# frozen_string_literal: true

module Fly
  class Headers
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, body = @app.call(env)
      response = Rack::Response.new(body, status, headers)
      response.set_header('Fly-Region', ENV['FLY_REGION'])
      response.finish
    end
  end
end
