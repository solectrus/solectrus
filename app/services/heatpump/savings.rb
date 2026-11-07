# The savings of the heat pump against the fossil heating in a timeframe, as
# the badge on the heat pump page shows them (see Heatpump::SavingsBadge and
# Heatpump::ComparisonAmounts). Each render of the stats of the heat pump
# shows the badge, and the comparison of a long timeframe reads the values
# of each day of it. So the amounts stay in the cache until one of their
# inputs changes: the summaries of the timeframe, the prices, the payments,
# the heating or the fuel prices. The page of the comparison calculates
# them anew each time.
class Heatpump::Savings
  # The amounts of the badge, each rounded to `precision`
  Amounts = Data.define(:precision, :heating_cost, :heatpump_cost) do
    def savings = heating_cost - heatpump_cost
  end
  public_constant :Amounts

  def initialize(timeframe, heating: Heatpump::Heating.current)
    @timeframe = timeframe
    @heating = heating
  end

  attr_reader :heating

  # Whether the timeframe has a comparison and the system its data (see
  # Heatpump::Comparison.available?). The badge and the compact link on a
  # phone share the answer, so the fuel prices load once.
  def available?
    return @available if defined?(@available)

    @available = Heatpump::Comparison.timeframe?(timeframe) && Heatpump::Comparison.available?(heating)
  end

  # The amounts, nil without a result (see Heatpump::Comparison#ready?).
  # The badge and the compact link on a phone share them. Without a heating
  # there is no result, so the cache is not asked.
  def amounts
    return @amounts if defined?(@amounts)
    return @amounts = nil unless heating.configured?

    values = Rails.cache.fetch(cache_key, expires_in: 1.day) { compute }
    @amounts = (Amounts.new(**values) if values)
  end

  private

  attr_reader :timeframe

  # The cache holds numbers only, so an entry of an older version of the app
  # reads without the classes of this one
  def compute
    comparison = Heatpump::Comparison.new(timeframe, heating:)
    return unless comparison.ready?

    amounts = Heatpump::ComparisonAmounts.new(comparison)
    { precision: amounts.precision, heating_cost: amounts.heating_cost.to_f, heatpump_cost: amounts.heatpump_cost.to_f }
  end

  # A summary of the timeframe changes when its day is built again. Today is
  # part of the key, because a relative timeframe like the current week
  # covers other days tomorrow.
  def cache_key
    from = timeframe.effective_beginning_date
    to = timeframe.effective_ending_date

    [
      'heatpump_savings',
      Date.current,
      from,
      to,
      Summary.where(date: from..to).cache_key_with_version,
      Price.all.cache_key_with_version,
      Heatpump::Payment.all.cache_key_with_version,
      heating.fuel_type,
      heating.efficiency,
      heating.fixed_costs,
      heating.fuel_prices.cache_version,
    ]
  end
end
