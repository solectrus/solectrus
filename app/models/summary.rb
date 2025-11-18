# == Schema Information
#
# Table name: summaries
#
#  date       :date             not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_summaries_on_updated_at  (updated_at)
#
class Summary < ApplicationRecord
  has_many :values,
           class_name: 'SummaryValue',
           dependent: nil, # will be deleted by foreign key cascade
           primary_key: :date,
           foreign_key: :date,
           inverse_of: :summary

  def self.reset!
    delete_all
    Rails.cache.clear
  end

  # A summary is considered fresh when updated on the next day after 01:00
  # The one hour is to allow for late updates (e.g. a collector or
  # Power-Splitter stills sends data for yesterday shortly after midnight)
  REQUIRED_DISTANCE = 60 # minutes after beginning of the next day
  public_constant :REQUIRED_DISTANCE

  # A current day is considered fresh if the last update has just taken place
  CURRENT_TOLERANCE = 5 # minutes ago
  public_constant :CURRENT_TOLERANCE

  def self.fresh?(timeframe)
    return if timeframe.now?

    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date

    missing_or_stale_days(from:, to:).empty?
  end

  def self.fresh_percentage(timeframe)
    return if timeframe.now?

    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date

    missing_count = missing_or_stale_days(from:, to:).length
    total_count = (to - from).to_i + 1
    fresh_count = total_count - missing_count

    (fresh_count * 100.0 / total_count)
  end

  def self.missing_or_stale_days(from:, to:)
    find_by_sql(
      [
        <<-SQL.squish,
          /* Generate a list of all days within the specified range
             and compare with existing summaries to find missing or stale entries */
          SELECT gs.date
          FROM generate_series(:from, :to, '1 day'::interval) AS gs(date)
          LEFT JOIN summaries s ON s.date = gs.date

          WHERE
            /* A day is considered MISSING when there is no summary for that date */
            s.date IS NULL

          OR
            /* A past day is considered STALE when updated before the end of that day + extra limit */
            s.date < :threshold_date
            AND s.updated_at < (s.date + INTERVAL :required_distance) AT TIME ZONE :time_zone AT TIME ZONE 'UTC'

          OR
            /* Today or a future day is considered STALE if the last update was beyond the allowed tolerance time */
            s.date >= :threshold_date
            AND s.updated_at < :current_tolerance_time
        SQL
        {
          from:,
          to:,
          time_zone: Time.zone.name,
          threshold_date:,
          current_tolerance_time: CURRENT_TOLERANCE.minutes.ago,
          required_distance: "#{1.day.in_minutes + REQUIRED_DISTANCE} minutes",
        },
      ],
    ).pluck(:date)
  end

  def fresh?(current_tolerance: CURRENT_TOLERANCE)
    threshold_time = date.beginning_of_day + 1.day + REQUIRED_DISTANCE.minutes

    updated_at >=
      (threshold_time.past? ? threshold_time : current_tolerance.minutes.ago)
  end

  def stale?(current_tolerance: CURRENT_TOLERANCE)
    !fresh?(current_tolerance:)
  end

  def self.threshold_date
    if REQUIRED_DISTANCE.minutes.ago.today?
      # We are beyond the required distance from yesterday. Only today is open.
      Date.current
    else
      # We are still within the early morning period. Yesterday is still open.
      Date.yesterday
    end
  end
end
