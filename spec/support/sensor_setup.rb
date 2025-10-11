# Sensor System Setup for Tests
# Ensures Sensor::Config is properly initialized before tests run

module SensorTestHelpers
  # Use method_missing to dynamically provide sensor helper methods
  # This approach works even when code is reloaded by Spring

  def method_missing(method_name, *args, **kwargs, &)
    method_str = method_name.to_s

    if method_str.start_with?('measurement_')
      sensor_name = method_str.sub('measurement_', '').to_sym
      Sensor::Config.measurement(sensor_name)
    elsif method_str.start_with?('field_')
      sensor_name = method_str.sub('field_', '').to_sym
      Sensor::Config.field(sensor_name)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    method_str = method_name.to_s
    method_str.start_with?('measurement_', 'field_') || super
  end

  # Helper to stub feature permissions
  def stub_feature(*features)
    allow(ApplicationPolicy.instance).to receive(:feature_enabled?) { |f|
      features.include?(f)
    }
    Sensor::Config.setup(ENV)
  end
end

# Setup sensor system when this file is loaded
Sensor::Config.setup(ENV)

RSpec.configure do |config|
  # Include the module with sensor helper methods
  config.include SensorTestHelpers

  # Reset sensor configuration after each test to prevent test pollution
  # Some tests call Sensor::Config.setup with modified ENV variables
  config.after do
    # Only reset if configuration was changed by the test
    # This is detected by checking if the current config differs from ENV
    Sensor::Config.setup(ENV) if Sensor::Config.instance.env != ENV
  end
end
