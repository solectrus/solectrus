# == Schema Information
#
# Table name: summaries
#
#  date       :date             not null, primary key
#  steps      :jsonb            not null
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

  # TRUNCATE creates new empty files instead of reading the old rows, so a
  # reset also works when a data page on disk is corrupted.
  def self.reset!
    connection.execute(
      "TRUNCATE #{SummaryValue.quoted_table_name}, #{quoted_table_name}",
    )
    Rails.cache.clear
  end

  # A summary is considered fresh when updated on the next day after 01:00
  # The one hour is to allow for late updates (e.g. a collector or
  # Power-Splitter stills sends data for yesterday shortly after midnight)
  REQUIRED_DISTANCE = 60 # minutes after beginning of the next day
  public_constant :REQUIRED_DISTANCE

  # A current day is considered fresh if the last update has just taken place.
  # This is the base tolerance for a single displayed day; for longer
  # timeframes it is scaled up (see #current_tolerance_minutes).
  CURRENT_TOLERANCE = 5 # minutes ago, per displayed day
  public_constant :CURRENT_TOLERANCE

  # Upper bound for the (scaled) current-day tolerance. Even for very long
  # timeframes (e.g. the running year) the current day is recomputed a few
  # times per day, so its last chart bar does not look frozen.
  MAX_CURRENT_TOLERANCE = 6.hours.in_minutes # minutes ago
  public_constant :MAX_CURRENT_TOLERANCE

  # How much of the timeframe is covered by an up-to-date summary, in percent.
  # A day on which one of the given steps waits is not up to date (see
  # .missing_or_stale_days_for).
  def self.fresh_percentage(timeframe, steps: [])
    return if timeframe.now?

    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date

    total_count = (to - from).to_i + 1
    fresh_count = total_count - missing_or_stale_days_for(timeframe, steps:).length

    (fresh_count * 100.0 / total_count)
  end

  # The same question for a whole timeframe: which of its days have no summary
  # yet, or a stale one. "Now" and the hour-resolution timeframes are answered
  # from raw measurements, so they need no summaries at all.
  #
  # `steps` also counts a day on which one of these steps waits (see
  # Summary::Steps). Only a caller that reads the records of a step asks for
  # it, so a new version of a step rebuilds no day for the other pages.
  def self.missing_or_stale_days_for(timeframe, steps: [])
    return [] if timeframe.now? || timeframe.hours?

    missing_or_stale_days(
      from: timeframe.effective_beginning_date,
      to: timeframe.effective_ending_date,
      steps:,
    )
  end

  def self.missing_or_stale_days(from:, to:, steps: [])
    find_by_sql(
      [
        <<~SQL.squish,
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

          OR
            /* A day is PENDING when one of the given steps did not run on it, or in an older version */
            EXISTS (
              SELECT 1 FROM jsonb_each_text(CAST(:versions AS jsonb)) AS v(key, version)
              WHERE COALESCE((s.steps->>v.key)::integer, 0) < v.version::integer
            )
        SQL
        {
          from:,
          to:,
          time_zone: Time.zone.name,
          threshold_date:,
          current_tolerance_time: current_tolerance_minutes(from:, to:).minutes.ago,
          required_distance: "#{1.day.in_minutes + REQUIRED_DISTANCE} minutes",
          versions: Summary::Steps.versions(steps.map { Summary::Steps[it] }.select(&:enabled?)).to_json,
        },
      ],
    ).pluck(:date)
  end

  # Acceptable staleness (in minutes) for the current day, scaled by the length
  # of the displayed timeframe. Recomputing the current day from InfluxDB is
  # expensive (especially on slow storage), so we only do it when it actually
  # matters for the view: in a day view the current day IS the whole chart, so
  # we stay at the base tolerance; in a year view it is just one of many bars,
  # so a much staler summary is acceptable. Capped by MAX_CURRENT_TOLERANCE.
  def self.current_tolerance_minutes(from:, to:)
    span_days = (to - from).to_i + 1
    [span_days * CURRENT_TOLERANCE, MAX_CURRENT_TOLERANCE].min
  end

  def fresh?(current_tolerance: CURRENT_TOLERANCE)
    threshold_time = date.beginning_of_day + 1.day + REQUIRED_DISTANCE.minutes

    updated_at >=
      (threshold_time.past? ? threshold_time : current_tolerance.minutes.ago)
  end

  def stale?(current_tolerance: CURRENT_TOLERANCE)
    !fresh?(current_tolerance:)
  end

  # Whether a step waits for the day: it did not run on it, or in an older
  # version (see Summary::Steps)
  def step_pending?(step)
    step.enabled? && steps.fetch(step::KEY.to_s, 0) < step::VERSION
  end

  # Whether a step with something to do waits for the day
  def steps_pending? = Summary::Steps.enabled.any? { step_pending?(it) }

  # The next build runs the step on the given days again
  def self.reset_step(key, days)
    where(date: days).update_all(['steps = steps - ?', key.to_s]) # rubocop:disable Rails/SkipsModelValidations
  end

  # The days on which the step with the key never ran
  scope :without_step, ->(key) { where('steps->>? IS NULL', key.to_s) }

  # Marks the step as run on the given days, in its current version
  def self.mark_step(step, days)
    where(date: days).update_all(['steps = steps || ?::jsonb', { step::KEY.to_s => step::VERSION }.to_json]) # rubocop:disable Rails/SkipsModelValidations
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
