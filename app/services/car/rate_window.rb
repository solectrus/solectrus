# Car::RateWindow gives the days of the window around a day of a car. The
# battery sits between charging and driving, so the car drives on energy that
# it charged on other days, too.
#
# The window is the day plus MARGIN_DAYS on each side (see Car::DailyRates). In
# the past, the window sits in the center, so a winter day keeps winter data.
# A window that reaches beyond today ends today, so a recent day has fewer
# days after it.
class Car::RateWindow
  # Days on each side of the period. Long enough that charge-vs-drive
  # imbalance (battery SoC) averages out, short enough to keep the season and
  # to fix a recent rate soon (see docs/cars.md for the measurement).
  MARGIN_DAYS = 14
  public_constant :MARGIN_DAYS

  # The days that a window of the car can hold: from the installation date
  # to today, inside the period of use of the car. Each window of the car
  # page ends at these bounds, so the rate of a new car holds no energy of
  # the car before it.
  def self.bounds(timeframe, car:, today: Date.current)
    [timeframe.min_date, car.active_from].compact.max..[today, car.active_until].compact.min
  end

  # The given dates plus MARGIN_DAYS on each side, inside the bounds.
  def self.with_margin(dates, bounds: nil..Date.current)
    from = [dates.begin - MARGIN_DAYS, bounds.begin].compact.max
    to = [dates.end + MARGIN_DAYS, bounds.end].compact.min

    from..to
  end
end
