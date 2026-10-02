# The charging cost of the selected cars (see CarSelectable): a column for
# each day, month or year, stacked from the costs of the charging sessions of
# the cars. With the power splitter, the cost of the own wallbox splits into
# PV and grid (see Car::ChargeSplit), and the offsite sessions are a part of
# their own. The columns add up to the charging cost of the car page.
#
# Now, the hours view and a day show the cost of the wallbox, like
# Sensor::Chart::WallboxCosts, because a session belongs to a full day.
class Sensor::Chart::CarChargingCosts < Sensor::Chart::WallboxCosts
  include Sensor::Chart::Concerns::CarSessions

  # Stacked from the bottom up: PV, grid, offsite, like the distance chart
  def chart_sensor_names
    super.reverse
  end

  private

  def session_datasets
    wallbox =
      if split?
        [
          session_dataset(cost_pv_sensor) { it.cost[:pv] },
          session_dataset(cost_grid_sensor) { it.cost[:grid] },
        ]
      else
        [
          build_cost_dataset(
            :wallbox_costs,
            Sensor::Registry[:wallbox_power].display_name,
            sessions_by_bucket.map { |sessions| presence(sessions.select(&:wallbox?).sum { it.cost.to_f }) },
            Sensor::Registry[:wallbox_power].color_background,
          ),
        ]
      end

    [
      *wallbox,
      build_cost_dataset(
        :offsite,
        ChargingSession.human_enum_name(:kind, :offsite),
        sessions_by_bucket.map { |sessions| presence(sessions.select(&:offsite?).sum { it.cost.to_f }) },
        'bg-sensor-offsite',
      ),
    ]
  end

  def session_dataset(sensor_name)
    build_cost_dataset(
      sensor_name,
      I18n.t(label_keys[sensor_name]),
      splits.map { presence(yield(it)) },
      color_class(Sensor::Registry[sensor_name]),
    )
  end
end
