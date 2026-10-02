# Car::Ledger holds the daily distance, energy and cost of one car for a date
# range, and gives the totals of any part of that range. A ledger reads its
# range one time, so the overlapping windows of a chart need no query each
# (see Car::RateWindow).
#
# The distance comes from the daily summaries of the odometer of the car. The
# energy and the cost come from the charging sessions of the car, without a
# proportional calculation: the detection stores the energy, the grid share
# and the cost of each wallbox session (see ChargingSession::Detection), and the
# user enters each offsite session. A guest session and a session that is not
# assigned belong to no car, so they count for no car.
#
# A session belongs to the local date of its start.
class Car::Ledger
  Totals =
    Data.define(:distance, :energy_wh, :cost, :uncosted) do
      # Whether each session has a cost. A wallbox session has no cost on a
      # day without a price, and a cost without it would be too small.
      def costed? = uncosted.zero?
    end
  public_constant :Totals

  EMPTY_DAY = { distance: 0.0, energy_wh: 0.0, cost: 0.0, uncosted: 0 }.freeze
  private_constant :EMPTY_DAY

  # `sessions` are charging sessions that the caller has already loaded. They
  # must hold each session of the car in the dates, and they can hold more.
  # Without them, the ledger reads the sessions of the car itself.
  def initialize(dates, car:, sessions: nil)
    @dates = dates
    @car = car
    @loaded_sessions = sessions
  end

  attr_reader :dates, :car

  # Totals of the given dates, by default the full range of the ledger. A day
  # outside the range of the ledger counts as empty. A total is the difference
  # of two running sums, so the window of each day of a long period costs no
  # sum of its days.
  def totals(range = dates)
    from = [range.begin, dates.begin].max
    to = [range.end, dates.end].min
    return Totals.new(**EMPTY_DAY) if from > to

    first = (from - dates.begin).to_i
    last = (to - dates.begin).to_i + 1
    Totals.new(**running_sums.transform_values { it[last] - it[first] })
  end

  private

  # { key => [0, day 1, day 1 + day 2, ...] }, in the order of the dates, so
  # an index is a day offset
  def running_sums
    @running_sums ||=
      EMPTY_DAY.to_h do |key, zero|
        [key, days.each_value.with_object([zero]) { |day, sums| sums << (sums.last + day[key]) }]
      end
  end

  def days
    @days ||=
      dates.index_with do |date|
        sessions = sessions_by_date.fetch(date, [])

        {
          distance: distances.fetch(date, 0.0),
          energy_wh: sessions.sum(&:kwh).to_f * 1000.0,
          cost: sessions.sum { it.cost.to_f },
          uncosted: sessions.count { it.cost.nil? },
        }
      end
  end

  # { date => distance } of the odometer of the car
  def distances
    @distances ||=
      SummaryValue
        .where(date: dates, field: Sensor::Cars.sensor_name(:car_mileage, car.id), aggregation: :sum)
        .pluck(:date, :value)
        .to_h
  end

  # { local date => [session, ...] }
  def sessions_by_date
    @sessions_by_date ||=
      if @loaded_sessions
        @loaded_sessions.select { it.car_id == car.id && dates.cover?(it.date) }.group_by(&:date)
      else
        car.charging_sessions.in_range(dates.begin.beginning_of_day, dates.end.end_of_day).group_by(&:date)
      end
  end
end
