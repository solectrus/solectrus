# Sensor System Setup
# Must be run after all Definition classes are loaded

Rails.application.config.after_initialize do
  extend RakeHelper

  unless skip_init_rake_task_running?
    Sensor::Registry.all
    Sensor::Config.setup(ENV)
  end
end

# In development: Reload on code changes
if Rails.env.development?
  Rails.application.reloader.to_prepare do
    Sensor::Registry.reset!
    Sensor::Registry.all

    # Clear caches and reload configuration
    Sensor::Config.setup(ENV)
  end
end
