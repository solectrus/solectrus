# The cost of the heat pump against a heating that burns oil or gas and makes
# the same heat (docs/heatpump.md). The admin sets the heating up (see
# Heatpump::Heating).
#
# The comparison has three columns:
#
# - The heat pump: its costs (see Sensor::Definitions::HeatpumpCosts). Grid
#   energy costs the electricity price, PV energy the lost feed-in revenue.
#   Its compared payments add to them (see Heatpump::Payment).
# - The heat pump without the PV system: the grid gives all its energy, at
#   the electricity price of each day, and the same payments add to it.
# - The heating: the fuel for the heat of the heat pump at the price of each
#   day (see FuelPrices), and its running costs per year, like the
#   maintenance and the chimney sweep (`fixed_cost`).
#
# Each side has its own running costs, so no payment of the heat pump counts
# for the fossil heating.
#
# The heat comes from the sensor of the generated heat. An estimate of the
# heat would show the estimate and not the measurement, so without the
# sensor there is no comparison. A day counts only with its heat, the costs
# of the heat pump, an electricity price and a fuel price, so the three
# columns make the same heat. The running costs of the heating count for
# each compared day, a 365th or a 366th of the yearly amount.
class Heatpump::Comparison
  # The sensors of the comparison: the heat, the energy and the costs of the
  # heat pump
  SENSORS = %i[heatpump_heating_power heatpump_power heatpump_costs].freeze
  private_constant :SENSORS

  # The sensors of the daily query. The costs come in their two parts, which
  # the query calculates in SQL, and the comparison adds them like
  # Sensor::Definitions::HeatpumpCosts. The sensor itself would add them in
  # Ruby for each day and load the grid energy as well, which the parts
  # need only in SQL. For the whole time (about 2500 days), the comparison
  # takes 65 ms with the sensor and 47 ms with the parts.
  QUERY_SENSORS = %i[heatpump_heating_power heatpump_power heatpump_costs_grid heatpump_costs_pv].freeze
  private_constant :QUERY_SENSORS

  # The sums of the compared days. The energies are in Wh.
  Totals = Data.define(:days, :heat_wh, :power_wh, :cost, :cost_without_pv, :fuel_wh, :fuel_cost, :fixed_cost)
  private_constant :Totals

  # Like the comparison of a car, the comparison takes each timeframe of
  # whole days, not the live view and not the last hours
  TIMEFRAME_KINDS = Car::Comparison::TIMEFRAME_KINDS
  public_constant :TIMEFRAME_KINDS

  # The comparison needs the heat and the costs of the heat pump, and the
  # prices of a fuel, which a collector writes. Without them, the comparison
  # and its settings stay out of sight. Any fuel counts, so the admin can
  # pick another fuel when the one of the heating has no prices. The fuel of
  # the heating comes first, so mostly only its prices load.
  def self.available?(heating = Heatpump::Heating.current)
    SENSORS.all? { Sensor::Config.exists?(it) } &&
      ((heating.configured? && heating.fuel_prices.any?) || FuelPrices.any?(Heatpump::Heating::FUEL_TYPES - [heating.fuel_type]))
  end

  def self.timeframe?(timeframe) = Car::Comparison.timeframe?(timeframe)

  # `days` are the compared days of a part of the timeframe, `daily_payments`
  # the payments of the whole (see #split)
  def initialize(timeframe, heating: Heatpump::Heating.current, days: nil, daily_payments: nil)
    @timeframe = timeframe
    @heating = heating
    @compared_days = days
    @daily_payments = daily_payments
  end

  attr_reader :timeframe, :heating

  # [[whole period, comparison], ...] of the years or the months (`by`) with
  # a compared day. Each comparison holds the compared days of its period,
  # so the data and the payments load once for all of them.
  def split(by)
    compared_days.group_by { it.date.public_send(:"beginning_of_#{by}") }.map do |start, days|
      [start..start.public_send(:"end_of_#{by}"), self.class.new(timeframe, heating:, days:, daily_payments:)]
    end
  end

  # Why the comparison has no result, nil with a result: :none without a
  # heating, :no_prices without the prices of its fuel, :no_heat without a
  # compared day with heat
  def state
    return :none unless heating.configured?
    return :no_prices if heating.fuel_prices.none?

    :no_heat unless heat_wh.positive?
  end

  def ready? = state.nil?

  delegate :days, :heat_wh, :power_wh, :cost, :cost_without_pv, :fuel_wh, :fuel_cost, :fixed_cost, to: :totals

  # { category => cost } of the compared payments of the heat pump (see
  # Heatpump::Payment::COMPARED), a category without a cost left out. The
  # payments of a year count for each compared day of it, an equal part of
  # their sum (see #daily_payments).
  def payment_costs
    @payment_costs ||= Heatpump::Payment::COMPARED.filter_map do |category|
      cost = compared_days.sum { |day| daily_payments[[category, day.date.year]] }
      [category, cost] if cost.nonzero?
    end.to_h
  end

  # The payments of the heat pump
  def payments = payment_costs.values.sum

  # The total cost of each column: the heat pump with and without the PV
  # system, and the fossil heating
  def total_cost = cost + payments
  def total_cost_without_pv = cost_without_pv + payments
  def heating_cost = fuel_cost + fixed_cost

  # The seasonal performance factor of the compared days: the heat for each
  # kWh of electricity
  def cop = (heat_wh / power_wh if power_wh.positive?)

  # The fuel in its unit of sale, like liters of heating oil
  def fuel_units = units_of(fuel_wh)

  # The dates from the first to the last compared day, nil without one. The
  # prices before the heat pump or after its last day compare nothing.
  def compared_dates = (compared_days.first.date..compared_days.last.date if compared_days.any?)

  # [[date, price], ...] of the fuel on the compared dates, for a stepped
  # line (see FuelPrices#series)
  def fuel_series = @fuel_series ||= compared_dates ? heating.fuel_prices.series(compared_dates) : []

  # [[date, price], [date, price]]: the lowest and the highest fuel price on
  # the compared dates, each with the date of its week or month, nil without
  # a price. The calculation and the chart of the prices show the same two.
  def fuel_price_extremes = (fuel_series.minmax_by(&:last) if fuel_series.any?)

  # The number of days with heat that the comparison leaves out, because
  # they have no costs of the heat pump or no price
  def left_out_days = @left_out_days ||= heat_days - days

  # Whether the costs hold each cost of the heat pump in the timeframe, so
  # the heat pump page shows the same costs. A day without heat or without
  # a price stays out, and then the heat pump page shows more.
  def whole_cost?
    grid = values_of(:heatpump_costs_grid)
    pv = values_of(:heatpump_costs_pv)
    all = grid.sum { |date, value| value && pv[date] ? value + pv[date] : 0 }
    (all - cost).abs < 0.005
  end

  # The filter of the list of the payments that the payments come from: the
  # compared categories, or some of them, in the years of the compared
  # dates. A part of a year has a part of its payments, and the list shows
  # them in full. Nil without a compared day.
  def payment_filter(categories = Heatpump::Payment::COMPARED)
    return unless compared_dates

    Heatpump::PaymentFilter.new(categories:, from: compared_dates.begin.beginning_of_year, to: compared_dates.end.end_of_year)
  end

  private

  # A day with its heat (Wh), its energy (Wh), its costs, its costs without
  # the PV system and the fuel price
  Day = Data.define(:date, :heat_wh, :power_wh, :cost, :cost_without_pv, :price)
  private_constant :Day

  def totals
    @totals ||= Totals.new(
      days: compared_days.size,
      heat_wh: compared_days.sum(&:heat_wh),
      power_wh: compared_days.sum(&:power_wh),
      cost: compared_days.sum(&:cost),
      cost_without_pv: compared_days.sum(&:cost_without_pv),
      fuel_wh: compared_days.sum { fuel_wh_of(it) },
      fuel_cost: compared_days.sum { units_of(fuel_wh_of(it)) * it.price },
      fixed_cost: compared_days.sum { fixed_cost_of(it.date) },
    )
  end

  # The energy of the fuel of a day, more than its heat by the efficiency
  def fuel_wh_of(day) = day.heat_wh / heating.efficiency_ratio

  # An energy of the fuel (Wh) in its unit of sale
  def units_of(fuel_wh) = fuel_wh / 1000.0 / heating.fuel.kwh_per_unit

  def fixed_cost_of(date) = heating.fixed_costs.to_f * day_share(date)

  # The part of a year that a day has
  def day_share(date) = 1.0 / Time.days_in_year(date.year)

  # { [category, year] => cost } of the compared payments for each day of
  # their year, in the years of the compared days. An expense costs its
  # amount, a refund lowers it. The sum of a year spreads over the days of
  # the heat pump in it (see #heatpump_days), so the first year counts its
  # payments in full, and the running year a part of them like the running
  # costs of the heating.
  def daily_payments
    @daily_payments ||= begin
      years = compared_days.map { it.date.year }.uniq
      payments = years.empty? ? [] : Heatpump::Payment.compared.where(date: Date.new(years.min)..Date.new(years.max).end_of_year)
      sums = payments.each_with_object(Hash.new(0)) { |payment, result| result[[payment.category, payment.date.year]] += -payment.signed_amount.to_f }
      Hash.new(0).merge(sums.to_h { |(category, year), sum| [[category, year], sum / heatpump_days(year)] })
    end
  end

  # The days of a year from the first day of the heat pump, all days of a
  # later year
  def heatpump_days(year)
    first = [Date.new(year), first_heat_date].compact.max
    (first.end_of_year - first).to_i + 1
  end

  # The first day with heat of all time, not only of the timeframe
  def first_heat_date
    return @first_heat_date if defined?(@first_heat_date)

    @first_heat_date = SummaryValue.where(field: :heatpump_heating_power, aggregation: :sum).where.not(value: ..0).minimum(:date)
  end

  def compared_days
    @compared_days ||= heating.configured? ? days_of_data : []
  end

  def days_of_data
    power = values_of(:heatpump_power)
    grid = values_of(:heatpump_costs_grid)
    pv = values_of(:heatpump_costs_pv)

    heat.filter_map do |date, heat_wh|
      day_of(date, heat_wh, power[date], grid[date] + pv[date]) if heat_wh && power[date] && grid[date] && pv[date]
    end
  end

  # A day with its prices, nil without an electricity price or a fuel price
  def day_of(date, heat_wh, power_wh, cost)
    electricity_price = schedule.at(:electricity, date)
    price = heating.fuel_prices.at(date)
    return unless electricity_price && price

    Day.new(date:, heat_wh:, power_wh:, cost:, cost_without_pv: power_wh / 1000.0 * electricity_price, price:)
  end

  # The days with heat, compared or not
  def heat_days = heat.count { |_, value| value }

  # { date => Wh } of the heat, which the compared days and the days with
  # heat both read
  def heat = @heat ||= values_of(:heatpump_heating_power)

  # { date => value } of a sensor
  def values_of(sensor_name) = series.public_send(sensor_name, :sum, :sum) || {}

  def series
    @series ||=
      Sensor::Query::Total
        .new(timeframe) do |q|
          QUERY_SENSORS.each { q.sum it, :sum }
          q.group_by :day
        end
        .call
  end

  def schedule = @schedule ||= Price::Schedule.new
end
