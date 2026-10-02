# Car::DailyRates gives each day of one car the rates of the window around it:
# the day plus Car::RateWindow::MARGIN_DAYS on each side, inside
# Car::RateWindow.bounds. The battery sits between charging and driving, so a
# day alone gives a wrong rate (see Car::Balance for the rationale).
#
# Each day drives its distance at the rates of its own window. The driving of
# a period is the sum of its days, so the driving cost and the driven energy
# add up: the days give the month, and the months give the year. A rate of a
# period is this sum divided by the distance. The selection "all" adds the
# cars (see .for).
#
# A window with less than MIN_DISTANCE or without charged energy gives no
# rate, because a single charge would decide it. Such a day has no driving
# cost, and its distance does not count for a rate. A window with a session
# without a cost gives no cost rate, because its cost is too small.
class Car::DailyRates
  MIN_DISTANCE = 100
  public_constant :MIN_DISTANCE

  # The driving of a date range. The distance holds only the days with an
  # energy rate, and the cost distance only the days with a cost rate.
  Totals =
    Data.define(:distance, :energy_wh, :cost_distance, :cost) do
      def self.empty = new(distance: 0.0, energy_wh: 0.0, cost_distance: 0.0, cost: 0.0)

      def +(other)
        Totals.new(
          distance: distance + other.distance,
          energy_wh: energy_wh + other.energy_wh,
          cost_distance: cost_distance + other.cost_distance,
          cost: cost + other.cost,
        )
      end

      def rated?
        distance.positive?
      end

      def cost_rated?
        cost_distance.positive?
      end

      # Energy is in Wh, so /10 turns Wh per km into kWh per 100 km
      def consumption_per_100km
        (energy_wh / 10.0).fdiv(distance) if rated?
      end

      def cost_per_100km
        (cost * 100.0).fdiv(cost_distance) if cost_rated?
      end
    end
  public_constant :Totals

  # The charged energy and cost of a window for each km of the window. The
  # cost is nil when a session of the window has no cost.
  Rate = Data.define(:wh_per_km, :cost_per_km)
  public_constant :Rate

  # The rates of the given cars. Several cars add up, each with the rates of
  # its own windows. `sessions` are charging sessions that the caller has
  # already loaded (see Car::Ledger).
  def self.for(timeframe, cars, sessions: nil)
    rates =
      cars.map do |car|
        new(
          timeframe.effective_beginning_date..timeframe.effective_ending_date,
          car:,
          bounds: Car::RateWindow.bounds(timeframe, car:),
          sessions:,
        )
      end

    Sum.new(rates)
  end

  def initialize(dates, car:, bounds: nil..Date.current, sessions: nil)
    @dates = dates
    @car = car
    @bounds = bounds
    @sessions = sessions
  end

  attr_reader :dates, :car

  # The driving of the given dates, by default all dates. The days of the
  # range are a slice of the days, so the columns of a chart read each day
  # one time.
  def totals(range = dates)
    from = [range.begin, dates.begin].max
    to = [range.end, dates.end].min
    return Totals.empty if from > to

    day_list[(from - dates.begin).to_i..(to - dates.begin).to_i].compact.sum(Totals.empty)
  end

  # The rate of the window around the date, or nil without a rate. The days
  # of the window outside ledger_dates count as empty.
  def rate_on(date)
    window = ledger.totals(window_of(date..date))
    return if window.distance < MIN_DISTANCE || !window.energy_wh.positive?

    Rate.new(
      wh_per_km: window.energy_wh / window.distance,
      cost_per_km: (window.cost / window.distance if window.costed?),
    )
  end

  # The days that the rates read, inside the bounds
  def ledger_dates
    window_of(dates)
  end

  private

  attr_reader :bounds

  def window_of(range)
    Car::RateWindow.with_margin(range, bounds:)
  end

  # The days in the order of the dates, so an index is a day offset
  def day_list
    @day_list ||= days.values
  end

  # { date => Totals of the day at the rate of its window, or nil }
  def days
    @days ||=
      dates.index_with do |date|
        next unless bounds.cover?(date)

        distance = ledger.totals(date..date).distance
        rate = rate_on(date) if distance.positive?
        next unless rate

        cost_distance = rate.cost_per_km ? distance : 0.0
        Totals.new(
          distance:,
          energy_wh: distance * rate.wh_per_km,
          cost_distance:,
          cost: cost_distance * (rate.cost_per_km || 0.0),
        )
      end
  end

  def ledger
    @ledger ||= Car::Ledger.new(ledger_dates, car:, sessions: @sessions)
  end

  # The rates of several cars as one: the totals add up, and a day of each
  # car keeps the rate of its own window.
  class Sum
    def initialize(rates)
      @rates = rates
    end

    attr_reader :rates

    def totals(range = nil)
      rates.sum(Totals.empty) { range ? it.totals(range) : it.totals }
    end

    # The days that the rates of all cars read without a fresh summary or
    # without a detection (see Summary.missing_or_stale_days). Without a car
    # there is nothing to read.
    def missing_or_stale_days
      ranges = rates.map(&:ledger_dates).reject { it.begin > it.end }
      return [] if ranges.empty?

      Summary.missing_or_stale_days(
        from: ranges.map(&:begin).min,
        to: ranges.map(&:end).max,
        charging_sessions: true,
      )
    end
  end
  public_constant :Sum
end
