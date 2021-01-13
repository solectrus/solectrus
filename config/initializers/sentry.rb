Sentry.init do |config|
  config.dsn = Rails.configuration.x.sentry_dns
  config.breadcrumbs_logger = [:active_support_logger]
  config.send_default_pii = true
  config.enabled_environments = %w[production]
end
