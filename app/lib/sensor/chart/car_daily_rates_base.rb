# Base of the charts with a column for each bucket of the selected cars, from
# the rates of its days. Each day drives at the rate of the window around it
# (see Car::DailyRates), so a month column shows the same number as the tile
# of that month. The distance of a day comes from the daily summaries, so a
# bucket must be a day at least.
#
# Each subclass defines #value, the number of a column from its totals.
class Sensor::Chart::CarDailyRatesBase < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarBuckets
  include Sensor::Chart::Concerns::SelectedCars

  def self.supports?(timeframe)
    !timeframe.short?
  end

  # Each column is a number of its own, and a line would suggest a flow.
  def type
    'bar'
  end

  private

  def build_data
    return if !supported? || buckets.none?

    sensor = chart_sensors.first
    totals = buckets.map { daily_rates.totals(it) }
    values = totals.map { value(it) }
    {
      labels: buckets.map { timestamp_to_ms(it.begin) },
      datasets: [
        {
          **style_for_sensor(sensor),
          id: sensor.name.to_s,
          label:,
          data: values,
          tooltipNotes: totals.zip(values).map { |sum, value| notes(sum) if value },
          hatchFill: buckets.map { partial?(it) },
        },
      ],
    }
  end

  # A column without each day of its calendar period, because the
  # installation date, today or the edge of a range cuts it, is hatched.
  def partial?(bucket)
    case sql_grouping_period
    when :year then bucket != bucket.begin.all_year
    when :month then bucket != bucket.begin.all_month
    else false
    end
  end

  # The value of a column, or nil without a rate
  def value(_totals)
    # simplecov:disable
    raise NotImplementedError
    # simplecov:enable
  end

  # The lines below the value in the tooltip
  def notes(_totals)
    [daily_rate_note]
  end

  def daily_rates
    @daily_rates ||= Car::DailyRates.new(timeframe, cars)
  end

  def daily_rate_note
    I18n.t('car_breakdown.daily_rate', days: Car::DailyRates::MARGIN_DAYS)
  end
end
