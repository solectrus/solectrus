require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
# require "active_storage/engine"
require 'action_controller/railtie'
# require 'action_mailer/railtie'
# require "action_mailbox/engine"
# require "action_text/engine"
require 'action_view/railtie'
require 'action_cable/engine'
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Solectrus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks middleware])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = ENV.fetch('TZ', 'Europe/Berlin')

    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    config.exceptions_app = ->(env) { ErrorsController.action(:show).call(env) }

    # Add custom error status codes
    config.action_dispatch.rescue_responses['ForbiddenError'] = :forbidden

    # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
    # the I18n.default_locale when a translation cannot be found).
    config.i18n.available_locales = %i[en de]
    config.i18n.default_locale = :en

    config.x.app_host = ENV.fetch('APP_HOST', nil).presence
    config.x.frame_ancestors = ENV.fetch('FRAME_ANCESTORS', nil).presence
    config.x.plausible_url = ENV['PLAUSIBLE_URL'].presence
    config.x.honeybadger.api_key = ENV['HONEYBADGER_API_KEY'].presence
    config.x.rorvswild.api_key = ENV['RORVSWILD_API_KEY'].presence
    config.x.co2_emission_factor = ENV.fetch('CO2_EMISSION_FACTOR', 401).to_i # g / kWh

    config.x.influx.token = ENV.fetch('INFLUX_TOKEN', nil)
    config.x.influx.schema = ENV.fetch('INFLUX_SCHEMA', 'http')
    config.x.influx.host = ENV.fetch('INFLUX_HOST', nil)
    config.x.influx.port = ENV.fetch('INFLUX_PORT', 8086)
    config.x.influx.bucket = ENV.fetch('INFLUX_BUCKET', nil)
    config.x.influx.org = ENV.fetch('INFLUX_ORG', nil)

    config.x.influx.poll_interval = ENV.fetch('INFLUX_POLL_INTERVAL', '5').to_i

    config.after_initialize do
      def rake_task_running?(*tasks)
        tasks.any? do |task|
          defined?(Rake) && Rake.application.top_level_tasks.include?(task)
        end
      end

      unless rake_task_running?(
               'assets:precompile',
               'db:create',
               'db:migrate',
               'db:prepare',
             )
        SensorConfig.setup(ENV)
        ThemeConfig.setup(ENV)

        ActiveRecord::Base.connection_pool.with_connection do
          if ActiveRecord::Base.connection.table_exists?(:settings)
            # Ensure settings are seeded on every start
            Setting.seed!

            # Validate summaries on every start
            if ActiveRecord::Base.connection.table_exists?(:summaries)
              Summary.validate!
            end
          end
        end
      end

      if Rails.cache.respond_to?(:redis)
        # Check Redis connection
        begin
          Rails.cache.redis.with(&:ping)
          Rails.logger.info 'Redis available, cache enabled'
        rescue Redis::CannotConnectError => e
          Rails.logger.error "Redis unavailable: #{e.message}"
        end
      end
    end

    config.x.installation_date =
      Date.parse ENV.fetch('INSTALLATION_DATE', '2020-01-01')

    config.x.admin_password = ENV.fetch('ADMIN_PASSWORD', nil).presence

    # Disable preloading JS/CSS via Link header to avoid browser warnings like this one:
    # "... was preloaded using link preload but not used within a few seconds ..."
    config.action_view.preload_links_header = false

    # End2End tests with Cypress uses time traveling to a date BEFORE the migrations.
    # This does not work with Rails 7.2 by default, so we disable the timestamp check.
    # TODO: Fix the time traveling in the Cypress tests and remove this line.
    config.active_record.validate_migration_timestamps = false
  end
end
