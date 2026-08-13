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
# Note: This may be redundant if after_initialize already ran, but ensures config is set up
Sensor::Config.setup(ENV)

RSpec.configure do |config|
  # Include the module with sensor helper methods
  config.include SensorTestHelpers

  # Restore the configured sensors before each test, because they are process
  # state three different things rewrite: `Sensor::Config.setup` with a
  # modified env, `stub_feature`, and every spec that leaves a registration
  # state in the UpdateCheck cache - permissions decide which sensors exist, so
  # a cached "unregistered" cuts the set from 194 sensors to 63.
  #
  # Recognized by the RESULT rather than by its causes: the sensor names are
  # compared against the set the suite started with. The former guard compared
  # the env alone, which named only the first cause - so a spec inherited a
  # foreign sensor set, and one reading Sensor::Config.sensors passed or failed
  # by test order.
  #
  # BEFORE rather than after, because a stub is still installed while the after
  # hooks run: rebuilding there would memoize the stubbed answer again.
  baseline = nil

  config.before do
    baseline ||= Sensor::Config.sensors.map(&:name)
    next if Sensor::Config.instance.env == ENV && Sensor::Config.sensors.map(&:name) == baseline

    # Drops the cached registration state as well, which the permissions - and
    # with them the sensor set - are computed from.
    UpdateCheck.clear_cache!
    Sensor::Config.setup(ENV)
  end
end
