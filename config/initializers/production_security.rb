if Rails.env.production?
  Rails.application.config.hosts = [ ENV.fetch("APP_HOST", "invoices.callummacleod.ca") ]
  Rails.application.config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
  Rails.application.config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }
end
