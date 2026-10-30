# The weekly prices of the fuel of the combustion car in a timeframe, as a
# stepped line in a modal (see Cars::FuelPricesController). The lowest and
# the highest price stand above it. The modal shows no average: the
# comparison weighs the prices by the distance, and a plain average beside
# it would confuse. The axis shows the timeframe, so the modal does not name
# it.
class Car::FuelPriceChart::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # The title of the modal names the fuel if each car has the same
  def self.title(comparison)
    fuel_types = comparison.cars.map(&:fuel_type).uniq
    I18n.t(fuel_types.one? ? "car_comparison.fuel_prices_of.#{fuel_types.sole}" : 'car_comparison.fuel_prices')
  end

  def initialize(comparison:)
    super()
    @comparison = comparison
  end

  attr_reader :comparison

  # [[label, value, date], ...]: the lowest and the highest price, each with
  # the date of its week. Up to a quarter has the day, a longer timeframe the
  # month. A price without a change stands alone.
  def figures
    lowest, highest = comparison.fuel_price_extremes
    return [] unless lowest
    return [[t('.price'), per_liter(lowest.last), nil]] if lowest.last == highest.last

    { lowest:, highest: }.map { |key, (date, price)| [t(".#{key}"), per_liter(price), l(date, format: t(comparison.dates.count > 92 ? '.month_format' : '.day_format'))] }
  end

  # A line for each fuel
  def chart_data
    {
      lines: comparison.fuel_series.map do |fuel_type, points|
        { label: Car.human_enum_name(:fuel_type, fuel_type), points: points.map { |date, price| { x: date.iso8601, y: price } } }
      end,
    }
  end
end
