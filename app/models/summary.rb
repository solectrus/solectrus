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
  TODAY_TOLERANCE_IN_MINUTES = 5
  public_constant :TODAY_TOLERANCE_IN_MINUTES

  scope :completed,
        lambda {
          where(
            "DATE(updated_at) > date OR (DATE(updated_at) = date AND updated_at > (NOW() - INTERVAL '#{TODAY_TOLERANCE_IN_MINUTES} MINUTE'))",
          )
        }

  scope :outdated,
        lambda {
          where(
            "DATE(updated_at) <= date AND (DATE(updated_at) != CURRENT_DATE OR updated_at <= (NOW() - INTERVAL '#{TODAY_TOLERANCE_IN_MINUTES} MINUTE'))",
          )
        }

  def self.completed?(timeframe)
    completion_rate(timeframe) == 100
  end

  def self.completion_rate(timeframe)
    raise ArgumentError if timeframe.now?

    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date
    completed_count = where(date: from..to).completed.count

    days = (to - from).to_i + 1
    (completed_count * 100.0 / days)
  end

  def self.missing_days(timeframe)
    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date

    # Find dates with existing summaries
    existing_days = Summary.where(date: from..to).pluck(:date)

    # Find dates without a summary
    date_range = (from..to).to_a
    missing_days = date_range - existing_days

    # Find dates with an outdated summary
    outdated_days = Summary.outdated.where(date: from..to).pluck(:date)

    # Combine both lists
    missing_days + outdated_days
  end
end
