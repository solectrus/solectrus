# The prices of a fuel in a timeframe, as a stepped line in a modal: the
# weekly prices of the fuel of the combustion car (see
# Cars::FuelPricesController), and the prices of the fuel of the fossil
# heating that the heat pump compares with (see
# Heatpump::SavingsController#fuel_prices). The lowest and the highest
# price stand above it. The modal shows no average: the comparison weighs
# the prices by the distance or the heat, and a plain average beside it
# would confuse. The axis shows the timeframe, so the modal does not name
# it.
class Car::FuelPriceChart::Component < ViewComponent::Base
  include Car::ComparisonFormat

  # The title of the modal names the fuel if each car has the same
  def self.title(comparison)
    fuel_types = comparison.cars.map(&:fuel_type).uniq
    I18n.t(fuel_types.one? ? "car_comparison.fuel_prices_of.#{fuel_types.sole}" : 'car_comparison.fuel_prices')
  end

  # The chart of the fuels of the cars of a comparison (see Car::Comparison)
  def self.for(comparison)
    lines = comparison.fuel_series.transform_keys { Car.human_enum_name(:fuel_type, it) }
    new(lines:, extremes: comparison.fuel_price_extremes, days: comparison.dates.count)
  end

  # `lines` are { label => [[date, price], ...] }, a line for each fuel.
  # `extremes` are the lowest and the highest price, each [date, price],
  # nil without a price. `days` is the length of the timeframe, which
  # chooses the format of the dates. A price has `unit` after it and
  # `precision` decimals.
  def initialize(lines:, extremes:, days:, unit: 'l', precision: 2)
    super()
    @lines = lines
    @extremes = extremes
    @days = days
    @unit = unit
    @precision = precision
  end

  attr_reader :unit, :precision

  # [[label, value, date], ...]: the lowest and the highest price, each with
  # the date of its week or month. Up to a quarter has the day, a longer
  # timeframe the month. Two prices that look the same stand as one (see
  # Car::ComparisonFormat#shown_prices).
  def figures
    lowest, highest = @extremes
    return [] unless lowest
    return [[t('.price'), price(lowest.last), nil]] if shown_prices(lowest.last, highest.last, precision:).one?

    { lowest:, highest: }.map { |key, (date, value)| [t(".#{key}"), price(value), l(date, format: t(@days > 92 ? '.month_format' : '.day_format'))] }
  end

  def chart_data
    { lines: @lines.map { |label, points| { label:, points: points.map { |date, value| { x: date.iso8601, y: value } } } } }
  end

  private

  def price(value) = "#{currency(value, precision:)}/#{unit}"
end
