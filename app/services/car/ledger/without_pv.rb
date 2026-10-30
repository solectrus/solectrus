# A ledger as if the grid gave all the energy of the wallbox: each kWh at the
# electricity price of the day. An offsite session keeps its cost. A day
# before the first electricity price has no cost for its wallbox sessions.
# The car without the PV system of the comparison with a combustion car
# drives on it (see Car::Comparison), and each other value is the one of the
# ledger.
class Car::Ledger::WithoutPv < SimpleDelegator
  def daily_sessions(car, date)
    sessions = super
    wallbox = daily_kind_sessions(car, date, 'wallbox')
    return sessions if wallbox.rows.zero?

    offsite = daily_kind_sessions(car, date, 'offsite')
    price = electricity_price(date)
    sessions.with(
      cost: offsite.cost + (price ? wallbox.kwh * price : 0.0),
      uncosted: offsite.uncosted + (price ? 0 : wallbox.rows),
    )
  end

  private

  # The electricity price (per kWh) of a date, nil before the first price
  def electricity_price(date)
    (@price_schedule ||= Price::Schedule.new).at(:electricity, date)
  end
end
