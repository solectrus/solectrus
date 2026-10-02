# The driving cost of the car: each day drives its distance at the cost per km
# of the window around it (see Car::DailyRates). A column is the sum of its
# days, so it shows the same number as the driving cost tile of that period,
# and the columns add up to the tile of the timeframe.
#
# The tooltip of a column shows this calculation and says that each day has
# a window of its own.
class Sensor::Chart::CarDrivingCosts < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarDailyRates

  # The distance of a column comes from the daily summaries, so a column must
  # be a day at least.
  def self.supports?(timeframe)
    !timeframe.short?
  end

  def chart_sensor_names
    %i[car_driving_costs]
  end

  private

  def build_data
    build_bucket_data if supported?
  end

  def value(totals)
    totals.cost if totals.cost_rated?
  end

  # The calculation of the value (distance times rate) comes first.
  def notes(totals)
    [calculation(totals.cost_distance, totals.cost_per_100km / 100), daily_rate_note]
  end

  def calculation(distance, cost_per_km)
    rate_unit = Sensor::UnitFormatter.format(unit: :money_per_100km, context: :total)
    "#{Sensor::ValueFormatter.new(distance, unit: :kilometer)} × #{number(cost_per_km * 100, 2)} #{rate_unit}"
  end

  def number(value, precision)
    ActiveSupport::NumberHelper.number_to_rounded(value, precision:, delimiter: I18n.t('number.format.delimiter'))
  end
end
