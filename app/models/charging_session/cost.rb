# The cost of a wallbox session from the prices of its day. The grid share
# costs the electricity price and the PV share the feed-in price. Without
# the power splitter there is no grid share, and the full energy gets the
# electricity price. Without a price there is no cost, because zero is a
# wrong number.
#
# The detection prices a session when it finds it, and a change of a price
# prices the sessions of its days again (see ChargingSession.reprice).
class ChargingSession::Cost
  def initialize(prices = Price::Schedule.new)
    @prices = prices
  end

  # [cost, cost of the grid share]. The cost of the PV share is the rest, so
  # the parts add up to the cost. The detection keeps the grid share within
  # the energy, so the PV share is never negative.
  def call(date, kwh, kwh_grid)
    electricity = prices.at(:electricity, date)
    return [nil, nil] unless electricity
    return [(kwh * electricity).round(2), nil] unless kwh_grid

    feed_in = prices.at(:feed_in, date)
    return [nil, nil] unless feed_in

    grid = kwh_grid * electricity
    [(grid + ((kwh - kwh_grid) * feed_in)).round(2), grid.round(2)]
  end

  private

  attr_reader :prices
end
