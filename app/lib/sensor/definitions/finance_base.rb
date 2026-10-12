class Sensor::Definitions::FinanceBase < Sensor::Definitions::Base
  # The daily share of the base fee, as Sensor::Query::Helpers::Sql::CteBuilder
  # puts it into every row of the daily CTE. The builder names the column from
  # this constant as well, so both ends of the contract read the same string.
  BASE_FEE_COLUMN = 'pb_base_fee_per_day'.freeze
  public_constant :BASE_FEE_COLUMN

  def unit
    :money
  end

  def category
    :economic
  end

  def allowed_aggregations
    [:sum]
  end

  top10_permitted { ApplicationPolicy.finance_top10? }

  # Required price types (electricity, feed_in) - must be implemented by subclasses
  def required_prices
    # simplecov:disable
    raise NotImplementedError, 'Subclass must implement #required_prices'
    # simplecov:enable
  end

  # SQL calculation expression - must be implemented by subclasses
  # Available variables: s (sums table), pb (electricity price), pf (feed_in price)
  def sql_calculation
    # simplecov:disable
    raise NotImplementedError, 'Subclass must implement #sql_calculation'
    # simplecov:enable
  end

  # Ruby calculation for InfluxDB contexts - must be implemented by subclasses.
  # Receives the sensor's dependencies as keywords, plus the prices it declared
  # in #required_prices, keyed by price type.
  def calculate_with_prices(prices:, **)
    # simplecov:disable
    raise NotImplementedError, 'Subclass must implement #calculate_with_prices'
    # simplecov:enable
  end

  # Helper method to check if this finance definition needs a specific price type
  def needs_price?(price_type)
    required_prices.include?(price_type.to_sym)
  end

  # The electricity tariff has two parts: a rate per kWh, and a fixed monthly
  # amount for the grid connection. Whether this sensor carries that monthly
  # amount.
  #
  # The fee is never split: it does not grow with the consumption, so a share
  # of it would bill a consumer for costs it does not cause. A sensor carries
  # all of it or nothing.
  #
  # Declared once and read by both backends - #with_base_fee_sql builds the SQL
  # term from it, #with_base_fee the InfluxDB one - so a sensor cannot bill the
  # fee in one backend and forget it in the other.
  def carries_base_fee?
    false
  end

  # `base_fee` added to what #calculate_with_prices returned, where this sensor
  # carries the fee. The InfluxDB counterpart of #with_base_fee_sql.
  #
  # A missing reading cancels the energy costs, but not the fee: the fee buys
  # the grid connection and falls due whether the meter reports or not. Without
  # a fee the value stays nil, so a gap in the data keeps reading as a gap.
  def with_base_fee(value, base_fee)
    return value if base_fee.zero? || !carries_base_fee?

    value ? value + base_fee : base_fee
  end

  protected

  # `expression` plus the base fee that falls on one day of the daily CTE, where
  # this sensor carries the fee. Reads a NULL the way #with_base_fee reads a nil:
  # a missing expression leaves the fee alone, a missing fee the expression.
  def with_base_fee_sql(expression)
    return expression unless carries_base_fee?

    "COALESCE(#{expression} + #{BASE_FEE_COLUMN}, #{expression}, #{BASE_FEE_COLUMN})"
  end

  # The base fee term alone, zero on a day without a fee.
  def base_fee_sql
    coalesce(BASE_FEE_COLUMN)
  end

  # Helper for Wh to kWh conversion
  def to_kwh(wh_expression)
    "(#{wh_expression}) / 1000.0"
  end

  # Helper for building GREATEST expressions (for PV calculations)
  def greatest(expression, fallback = 0)
    "GREATEST(#{expression}, #{fallback})"
  end

  # Helper for building COALESCE expressions
  def coalesce(expression, fallback = 0)
    "COALESCE(#{expression}, #{fallback})"
  end
end
