# The charged energy of the selected cars (see CarSelectable): a column for
# each day, month or year, stacked from the charging sessions of the cars.
# The energy of the own wallbox splits into PV and grid with the power
# splitter, and the offsite sessions are a part of their own. A guest
# session and a session that is not assigned count for no car.
#
# Now, the hours view and a day show the power curve of the wallbox, because
# a session belongs to a full day.
class Sensor::Chart::CarCharging < Sensor::Chart::Base
  include Sensor::Chart::Concerns::CarSessions

  STACK = 'Car-Charging'.freeze
  private_constant :STACK

  private

  # Same rationale as Sensor::Chart::CustomPower: a wallbox reads 0 W while
  # idle but the collector typically stops writing instead of streaming
  # zeros. Bridge only cadence jitter in the now view (2 min, well below a
  # genuine idle phase); for day/hours views bridging is disabled so each
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

  def chart_sensor_names
    %i[wallbox_power]
  end

  def datasets(chart_data_items)
    [
      build_dataset(
        id: 'wallbox_power',
        label: Sensor::Registry[:wallbox_power].display_name,
        data: chart_data_items.first[:data],
        color_class: Sensor::Registry[:wallbox_power].color_background,
      ),
    ]
  end

  # From the bottom up: PV, grid, offsite
  def session_datasets
    wallbox =
      if split?
        [
          session_dataset(:wallbox_power_pv, I18n.t('splitter.pv')) { it.energy[:pv] },
          session_dataset(:wallbox_power_grid, I18n.t('splitter.grid')) { it.energy[:grid] },
        ]
      else
        [
          session_dataset(:wallbox_power, Sensor::Registry[:wallbox_power].display_name, &:wallbox_wh),
        ]
      end

    [
      *wallbox,
      build_dataset(
        id: 'offsite',
        label: ChargingSession.human_enum_name(:kind, :offsite),
        data: splits.map { presence(it.offsite_wh) },
        color_class: 'bg-sensor-offsite',
      ),
    ]
  end

  def session_dataset(sensor_name, label)
    build_dataset(
      id: sensor_name.to_s,
      label:,
      data: splits.map { presence(yield(it)) },
      color_class: Sensor::Registry[sensor_name].color_background,
    )
  end

  def build_dataset(id:, label:, data:, color_class:)
    {
      id:,
      label:,
      data:,
      stack: STACK,
      colorClass: color_class,
      fill: true,
      tension: 0.4,
      cubicInterpolationMode: 'monotone',
      borderSkipped: false,
      pointRadius: 0,
      pointHoverRadius: 5,
      barPercentage: 0.7,
      categoryPercentage: 0.7,
      borderRadius: 3,
      borderWidth: 1,
      noGradient: true,
    }
  end
end
