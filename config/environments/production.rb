require 'active_support/core_ext/integer/time'

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = {
    'X-Content-Type-Options' => 'nosniff',
    'cache-control' => 'public, s-maxage=31536000, max-age=31536000, immutable',
    'Expires' => 1.year.from_now.to_fs(:rfc822),
  }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = 'http://assets.example.com'
  config.asset_host = ENV.fetch('ASSET_HOST', nil).presence

  # The 'X-Frame-Options' header should not be used.  A similar effect, with more consistent
  # support and stronger checks, can be achieved with the 'Content-Security-Policy' header
  # and 'frame-ancestors' directive.
  config.action_dispatch.default_headers.delete 'X-Frame-Options'

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  config.assume_ssl =
    ActiveModel::Type::Boolean.new.cast ENV.fetch('FORCE_SSL', 'false')

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl =
    ActiveModel::Type::Boolean.new.cast ENV.fetch('FORCE_SSL', 'false')

  # Skip http-to-https redirect for the default health check endpoint.
  # config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)
  config.log_tags = [:remote_ip]

  # Use lograge gem
  config.lograge.enabled = true

  # Change to "debug" to log everything (including potentially personally-identifiable information!)
  config.log_level = ENV.fetch('RAILS_LOG_LEVEL', 'info')

  # Use a different cache store in production.
  config.cache_store = :redis_cache_store, { url: ENV.fetch('REDIS_URL', nil) }

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = '/up'

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # config.active_job.queue_adapter = :resque

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
