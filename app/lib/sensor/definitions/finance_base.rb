class Sensor::Definitions::FinanceBase < Sensor::Definitions::Base
  def unit
    :euro
  end

  def category
    :economic
  end

  def allowed_aggregations
    [:sum]
  end

  # Required price types (electricity, feed_in) - must be implemented by subclasses
  def required_prices
    # :nocov:
    raise NotImplementedError, 'Subclass must implement #required_prices'
    # :nocov:
  end

  # SQL calculation expression - must be implemented by subclasses
  # Available variables: s (sums table), pb (electricity price), pf (feed_in price)
  def sql_calculation
    # :nocov:
    raise NotImplementedError, 'Subclass must implement #sql_calculation'
    # :nocov:
  end

  # Ruby calculation for InfluxDB contexts - must be implemented by subclasses
  def calculate_with_prices(dependencies:, electricity_price:, feed_in_price:)
    # :nocov:
    raise NotImplementedError, 'Subclass must implement #calculate_with_prices'
    # :nocov:
  end

  # Helper method to check if this finance definition needs a specific price type
  def needs_price?(price_type)
    required_prices.include?(price_type.to_sym)
  end

  protected

  # Helper for building price references
  def electricity_price
    'pb.eur_per_kwh'
  end

  def feed_in_price
    'pf.eur_per_kwh'
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
