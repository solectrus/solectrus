# Sensor System Setup
# The initial setup is done in config/application.rb to ensure proper initialization order

# In development: Reload on code changes
if Rails.env.development?
  Rails.application.reloader.to_prepare do
    Sensor::Registry.reset!
    Sensor::Registry.all

    # NOTE: Sensor::Config is set up in application.rb (after_initialize)
    # and auto-reloaded in Sensor::Config
  end
end
