# Grid share of the battery discharge: the part of what the battery handed to
# the consumers that had been charged from the grid earlier.
#
# An older Power Splitter does not report this: the discharge then counts as PV
# entirely and this sensor stays empty.
#
# Unlike the other power_splitter sensors this one is not a consumer share but a
# second source of grid energy, see SummaryCorrector#grid_total.
class Sensor::Definitions::BatteryDischargingPowerGrid < Sensor::Definitions::Base
  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-sensor-grid',
        text: 'text-white dark:text-slate-400'

  aggregations stored: [:sum]

  requires_permission :power_splitter

  def corresponding_base_sensor
    Sensor::Registry[:battery_discharging_power]
  end
end
