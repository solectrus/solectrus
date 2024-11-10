class Calculator::QuerySql
  def initialize(from: nil, to: nil)
    super()

    @from = [from, Rails.application.config.x.installation_date].compact.max
    @to = to
  end

  attr_reader :from, :to

  def time
    totals[:max_updated_at]&.in_time_zone
  end

  def inverter_power
    totals[:sum_inverter_power_sum]
  end

  def inverter_power_forecast
    totals[:sum_inverter_power_forecast_sum]
  end

  def house_power
    totals[:sum_house_power_sum]
  end

  def house_power_grid
    totals[:sum_house_power_grid_sum]
  end

  def wallbox_power
    totals[:sum_wallbox_power_sum]
  end

  def wallbox_power_grid
    totals[:sum_wallbox_power_grid_sum]
  end

  def heatpump_power
    totals[:sum_heatpump_power_sum]
  end

  def heatpump_power_grid
    totals[:sum_heatpump_power_grid_sum]
  end

  def grid_import_power
    totals[:sum_grid_import_power_sum]
  end

  def grid_export_power
    totals[:sum_grid_export_power_sum]
  end

  def battery_charging_power
    totals[:sum_battery_charging_power_sum]
  end

  def battery_discharging_power
    totals[:sum_battery_discharging_power_sum]
  end

  private

  def totals
    @totals ||=
      Summary.where(date: from..to).calculate_all(
        # All summable sensor values
        :sum_inverter_power_sum,
        :sum_inverter_power_forecast_sum,
        :sum_house_power_sum,
        :sum_battery_charging_power_sum,
        :sum_battery_discharging_power_sum,
        :sum_grid_import_power_sum,
        :sum_grid_export_power_sum,
        :sum_wallbox_power_sum,
        :sum_heatpump_power_sum,
        :sum_house_power_grid_sum,
        :sum_wallbox_power_grid_sum,
        :sum_heatpump_power_grid_sum,
        # Latest updated_at
        :max_updated_at,
      )
  end
end
