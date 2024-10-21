class Calculator::QuerySql
  def initialize(from: nil, to: nil)
    super()

    @from = [from, Rails.application.config.x.installation_date].compact.max
    @to = [to, Date.current].compact.min
  end

  attr_reader :from, :to

  # Is the query result consired as up-to-date?
  def fresh?
    # Two conditions need to be met:
    # 1) There is a summary for each day in the timeframe
    # 2) The minimal difference `updated_at - date``is > 0. This
    #    means, the calcuation was made on the next day (or later)
    count == (to - from).to_i + 1 && update_diff&.positive?
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

  private

  def count
    totals[:count]
  end

  def update_diff
    totals[:update_diff]
  end

  def timezone_name
    Rails.application.config.time_zone
  end

  def totals
    @totals ||=
      Summary.where(date: from..to).calculate_all(
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
        #
        # The following columns are used to check the freshness of the result
        # A summary is considered fresh, if the `updated_at` is later than the `date`
        # On current day, a summary is fresh when updated_at is within the last 5 minutes
        #
        # Timezone conversion is necessary, because the `updated_at` column is in UTC (by Rails),
        # but the `date` column is stored in the local timezone
        :count,
        update_diff:
          "MIN(
             CASE
               WHEN date = DATE(NOW() AT TIME ZONE '#{timezone_name}')
                    AND updated_at AT TIME ZONE 'UTC' AT TIME ZONE '#{timezone_name}' >=
                        NOW() AT TIME ZONE '#{timezone_name}' - INTERVAL '#{Summary::TODAY_TOLERANCE} minutes'
                 THEN 1
               ELSE
                 DATE(updated_at AT TIME ZONE 'UTC' AT TIME ZONE '#{timezone_name}') - date
             END
        )",
      )
  end
end
