class TilesController < ApplicationController
  include ParamsHandling

  def show
  end

  private

  def calculator_now
    Calculator::Now.new(SensorConfig.x.inverter_sensor_names)
  end

  def calculator_range
    Calculator::Range.new(
      timeframe,
      calculations:
        (
          if sensor == :savings
            [
              *SensorConfig.x.inverter_sensor_names.map do |sensor_name|
                Queries::Calculation.new(sensor_name, :sum, :sum)
              end,
              Queries::Calculation.new(:house_power, :sum, :sum),
              Queries::Calculation.new(:heatpump_power, :sum, :sum),
              Queries::Calculation.new(:wallbox_power, :sum, :sum),
              Queries::Calculation.new(:grid_import_power, :sum, :sum),
              Queries::Calculation.new(:grid_export_power, :sum, :sum),
            ]
          else
            SensorConfig.x.inverter_sensor_names.map do |sensor_name|
              Queries::Calculation.new(sensor_name, :sum, :sum)
            end
          end
        ),
    )
  end
end
