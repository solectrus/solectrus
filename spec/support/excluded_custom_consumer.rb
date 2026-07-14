# A custom consumer excluded from house_power (INFLUX_EXCLUDE_FROM_HOUSE_POWER)
# is subtracted from house_power, so everything that needs the *complete*
# consumption (total_consumption, traditional_costs and thus savings) has to add
# it back. Shared by the specs covering that.
#
# No teardown needed: spec/support/sensor_setup.rb resets Sensor::Config after
# every example.
RSpec.shared_context 'with an excluded custom consumer' do
  let(:env) do
    {
      'INFLUX_SENSOR_HOUSE_POWER' => 'pv:house_power',
      'INFLUX_SENSOR_HEATPUMP_POWER' => 'pv:heatpump_power',
      'INFLUX_SENSOR_WALLBOX_POWER' => 'pv:wallbox_power',
      'INFLUX_SENSOR_GRID_IMPORT_POWER' => 'pv:grid_import_power',
      'INFLUX_SENSOR_GRID_EXPORT_POWER' => 'pv:grid_export_power',
      'INFLUX_SENSOR_CUSTOM_POWER_01' => 'consumer:power_01',
      'INFLUX_EXCLUDE_FROM_HOUSE_POWER' => 'CUSTOM_POWER_01',
    }
  end

  before { Sensor::Config.setup(env) }
end
