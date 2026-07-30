# What the home battery earned: PV that was stored instead of exported, and
# used later instead of buying from the grid.
#
# Only the PV share of both directions counts. Grid energy passing through the
# battery saves nothing: it was bought at the electricity price and is billed to
# whoever takes it out again through their own grid share, and it never had a
# feed-in revenue to lose in the first place.
class Sensor::Definitions::BatterySavings < Sensor::Definitions::FinanceBase
  depends_on { static_dependencies + grid_dependencies }

  def static_dependencies
    %i[battery_discharging_power battery_charging_power]
  end

  # The grid shares are optional: without them nothing is attributed to the
  # grid, and the whole flow counts as PV, as it always did.
  #
  # #pv_share_sql has to ask the same question, because a column it references
  # only gets built when the sensor is part of the dependencies -- so both go
  # through here rather than each calling Sensor::Config on its own.
  def grid_dependencies
    %i[battery_discharging_power_grid battery_charging_power_grid].select do
      Sensor::Config.exists?(it)
    end
  end

  def required_prices
    %i[electricity feed_in]
  end

  def sql_calculation
    # Resolved once: every #grid_dependencies asks Sensor::Config, which
    # resolves the feature flag behind the Power Splitter sensors.
    grid_deps = grid_dependencies

    # Savings from discharging PV (what you save by not buying from grid)
    # minus lost revenue from charging PV (what you lose by not feeding in)
    "(#{pv_share_sql(:battery_discharging_power, grid_deps)} * pb_money_per_kwh - " \
      "#{pv_share_sql(:battery_charging_power, grid_deps)} * pf_money_per_kwh) / 1000.0"
  end

  def calculate_with_prices(
    battery_discharging_power:,
    battery_charging_power:,
    prices:,
    battery_discharging_power_grid: nil,
    battery_charging_power_grid: nil
  )
    electricity_price = prices[:electricity]
    feed_in_price = prices[:feed_in]
    return unless electricity_price && feed_in_price

    discharge =
      pv_share(battery_discharging_power, battery_discharging_power_grid)
    charge = pv_share(battery_charging_power, battery_charging_power_grid)

    ((discharge * electricity_price) - (charge * feed_in_price)) / 1000.0
  end

  private

  # Whatever the Power Splitter did not attribute to the grid. Clamped at >= 0,
  # because the two are averaged separately and can cross by a rounding error.
  def pv_share(power, grid_share)
    [(power || 0) - (grid_share || 0), 0].max
  end

  def pv_share_sql(base, grid_deps)
    total = coalesce("#{base}_sum")
    return total if grid_deps.exclude?(:"#{base}_grid")

    greatest("#{total} - #{coalesce("#{base}_grid_sum")}")
  end
end
