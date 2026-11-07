# The prices of a fuel in InfluxDB. A fuel is anything that a car or a
# heating burns: petrol, diesel, LPG, heating oil and natural gas. Natural
# gas has a measurement of its own and a price for each month, the others a
# price for each week (see Sensor::Query::FuelPrices). The comparison with
# a combustion car (see Car::Comparison) and the comparison of the heat pump
# with a heating that burns oil or gas (see Heatpump::Comparison) read them.
#
# The prices are few, at most about 50 for each year, so they come directly
# from InfluxDB (see Sensor::Query::FuelPrices) and not from the daily
# summaries. A price holds until the next one, like the state of a car
# sensor, so the days after the last price keep it. A day before the first
# price has none.
class FuelPrices
  # The collector writes a new price once a week or once a month, so the
  # cache asks InfluxDB once an hour. An empty result holds as long, because
  # an installation can run without the collector for a long time.
  CACHE_TTL = 1.hour
  private_constant :CACHE_TTL

  # Whether a price of any of the fuels exists
  def self.any?(fuel_types) = fuel_types.any? { new(it).any? }

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

  # Whether a price exists, or none
  delegate :any?, :none?, to: :points

  # A digest of all prices, for the key of a cache that holds a result of
  # them. A new price changes it, and so does a corrected one.
  def cache_version = Digest::SHA256.hexdigest(points.to_s)

  private

  # [[date, price], ...], sorted by date. An empty result stays in the cache
  # too, so a page does not ask InfluxDB on each request. The prices are in
  # EUR, so another currency has none: they would mix with the electricity
  # prices in that currency.
  def points
    return @points = [] unless Currency.eur?

    @points ||= Rails.cache.fetch(['fuel-prices', fuel_type], expires_in: CACHE_TTL) { Sensor::Query::FuelPrices.new(fuel_type).call }
  end

  def dates = @dates ||= points.map(&:first)
  def prices = @prices ||= points.map(&:last)
end
