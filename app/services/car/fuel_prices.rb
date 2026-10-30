# The prices of a fuel (EUR per liter) in InfluxDB, one price for each week
# (docs/cars.md). The comparison with a combustion car reads them (see
# Car::Comparison).
#
# The prices are few, about 50 for each year, so they come directly from
# InfluxDB (see Sensor::Query::FuelPrices) and not from the daily summaries.
# A price holds until the next one, like the state of a car sensor, so the
# days after the last price keep it. A day before the first price has none.
class Car::FuelPrices
  # The collector writes a new price once a week. Without a price, the
  # collector can start later, so the cache asks again sooner.
  CACHE_TTL = 1.hour
  private_constant :CACHE_TTL

  EMPTY_CACHE_TTL = 5.minutes
  private_constant :EMPTY_CACHE_TTL

  # Whether a price of any fuel exists
  def self.any? = Car.fuel_types.keys.any? { new(it).any? }

  def initialize(fuel_type)
    @fuel_type = fuel_type.to_s
  end

  attr_reader :fuel_type

  # The price on a date, nil before the first price
  def at(date)
    index = dates.bsearch_index { it > date } || dates.size
    prices[index - 1] if index.positive?
  end

  # [[date, price], ...] of the dates for a stepped line: the price at the
  # first date, each new price after it, and the price at the last date
  def series(dates)
    inside = points.select { |date, _| date > dates.begin && date < dates.end }
    [[dates.begin, at(dates.begin)], *inside, [dates.end, at(dates.end)]].select(&:last)
  end

  # Whether a price exists
  delegate :any?, to: :points

  private

  # [[date, price], ...], sorted by date. An empty result stays in the cache
  # too, so the car page does not ask InfluxDB on each request. The prices
  # are in EUR, so another currency has none: they would mix with the
  # electricity prices in that currency.
  def points
    return @points = [] unless Currency.eur?

    @points ||=
      Rails.cache.fetch(['fuel-prices', fuel_type], expires_in: CACHE_TTL) do |_key, options|
        Sensor::Query::FuelPrices.new(fuel_type).call.tap { options.expires_in = EMPTY_CACHE_TTL if it.empty? }
      end
  end

  def dates = @dates ||= points.map(&:first)
  def prices = @prices ||= points.map(&:last)
end
