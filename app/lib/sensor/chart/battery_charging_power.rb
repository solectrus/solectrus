class Sensor::Chart::BatteryChargingPower < Sensor::Chart::BatteryPower
  # A stacked area needs the value axis stacked too, unlike the bars, which
  # Chart.js stacks from the index axis alone. Without it the grid and PV fills
  # would overlap instead of adding up to the total charging power.
  def options
    return super unless stacked_areas?

    super.deep_merge(scales: { y: { stacked: true } })
  end

  # The grid and PV fills are stacked and the discharging one sits below zero,
  # so nothing covers anything -- see Base#overlapping_datasets?. Without this
  # the chart would drop out of the translucent styling once it splits, purely
  # because it then has three datasets instead of two.
  def overlapping_datasets?
    false if splitting_allowed?
  end

  private

  def chart_sensor_names
    if splitting_allowed?
      %i[
        battery_charging_power_grid
        battery_charging_power_pv
        battery_discharging_power
      ]
    else
      super
    end
  end

  def style_for_sensor(sensor)
    if splitting_allowed?
      super.merge(split_style(sensor))
    else
      super
    end
  end

  # Bars stack through the dataset's stack group, areas through the value axis
  # (see #options) plus a fill that stops at the dataset below instead of at
  # the zero line -- the stacked axis only lifts the PV *line* onto the grid
  # one, its area would still be drawn all the way down and tint the grid area
  # underneath. Giving an area a stack group instead would cost it its gradient
  # -- ChartGradientDefault flattens every dataset carrying one, because a
  # gradient under a stacked *bar* would bleed into its neighbour.
  def split_style(sensor)
    return { stack: true } unless stacked_areas?
    return {} unless sensor.name == :battery_charging_power_pv

    { fill: '-1' }
  end

  # The split is drawn as stacked areas on the day view and as stacked bars
  # everywhere else -- the two stack through different means, see #split_style.
  def stacked_areas?
    splitting_allowed? && type == 'line'
  end

  # Asked once per dataset and several times by the base class, while resolving
  # the feature flag is the expensive part.
  def splitting_allowed?
    return @splitting_allowed if defined?(@splitting_allowed)

    @splitting_allowed =
      splittable_timeframe? && ApplicationPolicy.power_splitter? &&
        Sensor::Config.exists?(:battery_charging_power_grid)
  end

  # The bars have room to tell the two parts apart, and the day view draws areas
  # that stack just as well. The live views (now, and the hour ranges that share
  # their cadence) are out for a different reason: the Power Splitter only
  # writes every 5 minutes, so the split for the current moment isn't there yet.
  def splittable_timeframe?
    timeframe.day_like? || !timeframe.short?
  end
end
