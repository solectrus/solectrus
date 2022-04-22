require_relative 'boot'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_job/railtie'
require 'active_record/railtie'
# require "active_storage/engine"
require 'action_controller/railtie'
require 'action_mailer/railtie'
# require "action_mailbox/engine"
# require "action_text/engine"
require 'action_view/railtie'
require 'action_cable/engine'
require 'sprockets/railtie'
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Solectrus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    config.time_zone = 'Europe/Berlin'

    # config.eager_load_paths << Rails.root.join("extras")

    # Don't generate system test files.
    config.generators.system_tests = nil

    # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
    # the I18n.default_locale when a translation cannot be found).
    config.i18n.available_locales = %i[en de]
    config.i18n.default_locale = :de

    config.x.app_host = ENV.fetch('APP_HOST', nil)
    config.x.plausible_url = ENV['PLAUSIBLE_URL'].presence
    config.x.honeybadger.api_key = ENV['HONEYBADGER_API_KEY'].presence
    config.x.force_ssl =
      ActiveModel::Type::Boolean.new.cast ENV.fetch('FORCE_SSL', true)

    config.x.influx.token = ENV.fetch('INFLUX_TOKEN', nil)
    config.x.influx.schema = ENV.fetch('INFLUX_SCHEMA', 'http')
    config.x.influx.host = ENV.fetch('INFLUX_HOST', nil)
    config.x.influx.port = ENV.fetch('INFLUX_PORT', 8086)
    config.x.influx.bucket = ENV.fetch('INFLUX_BUCKET', nil)
    config.x.influx.org = ENV.fetch('INFLUX_ORG', nil)

    config.x.installation_date =
      Date.parse ENV.fetch('INSTALLATION_DATE', '2020-01-01')
    config.x.electricity_price = ENV.fetch('ELECTRICITY_PRICE', '0.25').to_f
    config.x.feed_in_tariff = ENV.fetch('FEED_IN_TARIFF', '0.08').to_f

    # Set the default layout to app/views/layouts/component_preview.html.slim
    config.view_component.default_preview_layout = 'component_preview'

    # The 'X-Frame-Options' header should not be used.  A similar effect, with more consistent
    # support and stronger checks, can be achieved with the 'Content-Security-Policy' header
    # and 'frame-ancestors' directive.
    config.action_dispatch.default_headers.delete 'X-Frame-Options'
  end
end
