# Sensor System Setup
# The initial setup is done in config/application.rb to ensure proper initialization order

# In development: Reload on code changes
if Rails.env.development?
  Rails.application.reloader.to_prepare do
    Sensor::Registry.reset!
    Sensor::Registry.all

    # Clear caches and reload configuration
    Sensor::Config.setup(ENV)
  end
end
