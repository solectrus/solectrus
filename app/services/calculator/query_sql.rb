class Calculator::QuerySql
  def initialize(from:, to:)
    super()

    @from = [from, Rails.application.config.x.installation_date].max
    @to = [to, Date.current].min
  end

  attr_reader :from, :to

  def ready?
    count == (to - from).to_i + 1
  end

  def reset!
    @totals = nil
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

  def count
    totals[:count]
  end

  private

  def totals
    @totals ||=
      Summary.where(date: from..to).calculate_all(
        :count,
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
      )
  end
end
