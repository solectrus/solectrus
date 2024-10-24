# == Schema Information
#
# Table name: summaries
#
#  avg_battery_soc               :float
#  avg_car_battery_soc           :float
#  avg_case_temp                 :float
#  date                          :date             not null, primary key
#  max_battery_charging_power    :float
#  max_battery_discharging_power :float
#  max_battery_soc               :float
#  max_car_battery_soc           :float
#  max_case_temp                 :float
#  max_grid_export_power         :float
#  max_grid_import_power         :float
#  max_heatpump_power            :float
#  max_house_power               :float
#  max_inverter_power            :float
#  max_wallbox_power             :float
#  min_battery_soc               :float
#  min_car_battery_soc           :float
#  min_case_temp                 :float
#  sum_battery_charging_power    :float
#  sum_battery_discharging_power :float
#  sum_grid_export_power         :float
#  sum_grid_import_power         :float
#  sum_heatpump_power            :float
#  sum_heatpump_power_grid       :float
#  sum_house_power               :float
#  sum_house_power_grid          :float
#  sum_inverter_power            :float
#  sum_inverter_power_forecast   :float
#  sum_wallbox_power             :float
#  sum_wallbox_power_grid        :float
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#
# Indexes
#
#  index_summaries_on_updated_at  (updated_at)
#
class Summary < ApplicationRecord
  # Check if the config have changed and reset the summaries if needed
  def self.validate!
    # If the stored config match the current ones, there is nothing to do
    if Setting.summary_config.to_json == config.to_json
      Rails.logger.info(
        'Configuration checked, no changes detected, summaries are still valid.',
      )
      return
    end

    # Configuration have changed, the existing summaries are no longer valid
    # Force a rebuild and remember the new config
    delete_all
    Setting.summary_config = config
    Rails.logger.info(
      'Summaries were invalid because the configuration has changed. Deleted all summaries, will rebuild.',
    )
  end

  # Configuration the summaries are based on
  # This hash is used to determine if the summaries are still valid
  #
  # Add more keys if needed
  def self.config
    {
      #
      # Version of the configuration. Increment this if the logic of the
      # summaries has changed. This will invalidate all existing summaries
      version: 1,
      #
      # The date column depends on the current timezone.
      # If the timezone changes, the summaries are no longer valid
      time_zone: Time.zone.name,
    }
  end

  # List of handled sensors extracted from the columns
  def self.sensors
    array =
      columns.filter_map do |column|
        if (match = column.name.match(/^(sum|avg|max|min)_(.*)/))
          match[2].to_sym
        end
      end

    array.uniq!
    array.sort!
    array
  end

  TODAY_TOLERANCE = 5 # minutes
  public_constant :TODAY_TOLERANCE

  scope :fresh,
        lambda {
          where(
            "DATE(updated_at AT TIME ZONE 'UTC' AT TIME ZONE :time_zone) > date
             OR (
               date >= :current_date
               AND updated_at > :current_tolerance_time
             )",
            time_zone: Time.zone.name,
            current_date: Date.current,
            current_tolerance_time: TODAY_TOLERANCE.minutes.ago,
          )
        }

  def self.fresh_percentage(timeframe)
    raise ArgumentError if timeframe.now?

    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date
    fresh_count = where(date: from..to).fresh.count

    total_days = (to - from).to_i + 1
    (fresh_count * 100.0 / total_days)
  end

  def self.missing_or_stale_days(from:, to:)
    find_by_sql(
      [
        <<-SQL.squish,
          SELECT gs.date
          FROM generate_series(:from, :to, '1 day'::interval) AS gs(date)
          LEFT JOIN summaries s ON s.date = gs.date
          WHERE s.date IS NULL
          OR (
            DATE(s.updated_at AT TIME ZONE 'UTC' AT TIME ZONE :time_zone) <= s.date
            AND (
              s.date < :current_date
              OR s.updated_at <= :current_tolerance_time
            )
          )
        SQL
        {
          from:,
          to:,
          time_zone: Time.zone.name,
          current_date: Date.current,
          current_tolerance_time: TODAY_TOLERANCE.minutes.ago,
        },
      ],
    ).pluck(:date)
  end

  def fresh?(today_tolerance: TODAY_TOLERANCE)
    updated_at.to_date > date ||
      (
        (date.today? || date.future?) &&
          updated_at >= today_tolerance.minutes.ago
      )
  end

  def stale?(today_tolerance: TODAY_TOLERANCE)
    !fresh?(today_tolerance:)
  end
end
