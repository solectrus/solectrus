class TilesController < ApplicationController
  include ParamsHandling

  def show
  end

  private

  def calculator_now
    Calculator::Now.new(%i[balcony_inverter_power inverter_power])
  end

  def calculator_range
    Calculator::Range.new(
      timeframe,
      calculations:
        (
          if sensor == :savings
            [
              Queries::Calculation.new(:inverter_power, :sum, :sum),
              Queries::Calculation.new(:balcony_inverter_power, :sum, :sum),
              Queries::Calculation.new(:house_power, :sum, :sum),
              Queries::Calculation.new(:heatpump_power, :sum, :sum),
              Queries::Calculation.new(:wallbox_power, :sum, :sum),
              Queries::Calculation.new(:grid_import_power, :sum, :sum),
              Queries::Calculation.new(:grid_export_power, :sum, :sum),
            ]
          else
            [
              Queries::Calculation.new(:inverter_power, :sum, :sum),
              Queries::Calculation.new(:balcony_inverter_power, :sum, :sum),
            ]
          end
        ),
    )
  end
end
