class TilesController < ApplicationController
  include ParamsHandling

  def show
  end

  private

  def calculations
    if sensor == :savings
      {
        inverter_power: :sum_inverter_power_sum,
        house_power: :sum_house_power_sum,
        heatpump_power: :sum_heatpump_power_sum,
        wallbox_power: :sum_wallbox_power_sum,
        grid_import_power: :sum_grid_import_power_sum,
        grid_export_power: :sum_grid_export_power_sum,
      }
    else
      { inverter_power: :sum_inverter_power_sum }
    end
  end
end
