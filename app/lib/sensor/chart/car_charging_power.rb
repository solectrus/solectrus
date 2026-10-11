# The charging power of now and a day on the car page: the power curve of the
# wallbox. A charging session belongs to a full day, so a shorter timeframe
# has no columns of sessions (see Sensor::Chart::CarSessions).
#
# A day leaves out the wallbox sessions that count for no selection (see
# Sensor::Chart::Concerns::WithoutOtherSessions).
#
# A day with the power splitter stacks the PV and the grid part of the
# wallbox, from the bottom up like the columns. The live view has no split,
# because the power splitter writes every 5 minutes.
#
# A day stacks the offsite sessions of the selected cars on the wallbox. An
# offsite session has no power curve, so the curves of its car tell when it
# charged (see ChargingSession::OffsiteProfile).
class Sensor::Chart::CarChargingPower < Sensor::Chart::Base
  include Sensor::Chart::Concerns::WithoutOtherSessions
  include Sensor::Chart::Concerns::OffsiteSessions

  # Without a wallbox there is no curve. The offsite sessions need a day at
  # least (see Sensor::Chart::CarSessions).
  def supported?
    super && Sensor::Config.exists?(:wallbox_power)
  end

  def chart_sensor_names
    splitting_allowed? ? %i[wallbox_power wallbox_power_pv wallbox_power_grid] : %i[wallbox_power]
  end

  # The parts stack, like the split of the battery (see
  # Sensor::Chart::BatteryChargingPower#options)
  def options
    return super unless stacked?

    super.deep_merge(scales: { y: { stacked: true } })
  end

  private

  def stacked?
    offsite_sessions.any? || data&.dig(:datasets)&.any? { it[:id] == 'wallbox_power_pv' }
  end

  def splitting_allowed?
    return @splitting_allowed if defined?(@splitting_allowed)

    @splitting_allowed = timeframe.day? && ApplicationPolicy.power_splitter? && Sensor::Config.exists?(:wallbox_power_grid)
  end

  # PV and grid instead of the wallbox, when the power splitter wrote them.
  # Without them, the power splitter does not run, and the wallbox stays.
  def datasets(chart_data_items)
    wallbox, pv, grid = chart_data_items.map { without_other_sessions(it) }
    split = [pv, grid].all? && [pv, grid].any? { it[:data].any?(&:positive?) }
    parts = split ? [split_dataset(pv, :pv), split_dataset(grid, :grid).merge(fill: '-1')] : super([wallbox])

    offsite_sessions.any? ? [*parts, offsite_dataset(wallbox[:labels])] : parts
  end

  def split_dataset(chart_data_item, source)
    build_dataset(chart_data_item[:sensor_name], chart_data_item).merge(
      label: I18n.t("splitter.#{source}"),
      colorClass: Car::ChargingSource[source].color_class,
    )
  end

  # Same rationale as Sensor::Chart::CustomPower: a wallbox reads 0 W while
  # idle but the collector typically stops writing instead of streaming
  # zeros. Bridge only cadence jitter in the now view (2 min, well below a
  # genuine idle phase); for the day view bridging is disabled so each
  # empty bucket stays a real idle phase.
  def gap_bridge_limit
    timeframe.now? ? 2.minutes.in_milliseconds : 0
  end

  # Flatten every remaining null to 0 W so the leading/trailing edges of
  # the now window -- and any genuine idle phase -- render as a baseline
  # instead of an empty area.
  def fill_gaps_with_zero?
    true
  end

  def build_dataset(sensor_name, chart_data)
    super.merge(stack: Sensor::Chart::CarSessions::STACKS[:energy], summed: true, noGradient: true)
  end

  # Straight edges, so the area of a session is a rectangle
  def offsite_dataset(labels)
    build_dataset(:wallbox_power, data: per_hour(offsite_sums(labels) { |_, energy| energy }).map(&:round)).merge(
      id: 'offsite',
      label: ChargingSession.human_enum_name(:kind, :offsite),
      colorClass: Car::ChargingSource[:offsite].color_class,
      fill: '-1',
      tension: 0,
      cubicInterpolationMode: 'default',
    )
  end
end
