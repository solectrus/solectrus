# The charging power of now and a day on the car page: the power curve of the
# wallbox. A charging session belongs to a full day, so a shorter timeframe
# has no columns of sessions (see Sensor::Chart::CarSessions).
#
# A day with the power splitter stacks the PV and the grid part of the
# wallbox, from the bottom up like the columns. The live view has no split,
# because the power splitter writes every 5 minutes.
#
# A day stacks the offsite sessions of the selected cars on the wallbox. An
# offsite session has no power curve, so the curves of its car tell when it
# charged (see ChargingSession::OffsiteProfile).
class Sensor::Chart::CarChargingPower < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars

  # The buckets of InfluxDB and of the offsite sessions
  BUCKET = Sensor::Query::Helpers::Influx::DailyCurves::BUCKET
  private_constant :BUCKET

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

  # Without wallbox data in InfluxDB, the offsite sessions get a grid of
  # their own, and the wallbox stays at 0 W (see #fill_gaps_with_zero?)
  def master_labels(items)
    labels = super
    labels.blank? && offsite_sessions.any? ? day_grid : labels
  end

  # PV and grid instead of the wallbox, when the power splitter wrote them.
  # Without them, the power splitter does not run, and the wallbox stays.
  def datasets(chart_data_items)
    wallbox, pv, grid = chart_data_items
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
    build_dataset(:wallbox_power, data: offsite_power(labels)).merge(
      id: 'offsite',
      label: ChargingSession.human_enum_name(:kind, :offsite),
      colorClass: Car::ChargingSource[:offsite].color_class,
      fill: '-1',
      tension: 0,
      cubicInterpolationMode: 'default',
    )
  end

  # The mean power (W) of the offsite sessions in each bucket. A label is the
  # end of its bucket, like the buckets of InfluxDB. A part of the profile
  # falls into one or two buckets and gives each its share, so a session
  # shorter than a bucket keeps its energy.
  def offsite_power(labels)
    return [] if labels.empty?

    start = (labels.first / 1000) - BUCKET.to_i
    energies = Array.new(labels.size, 0.0)
    ChargingSession::OffsiteProfile.new(offsite_sessions).call.each { |part| spread_wh(energies, start, *part) }

    energies.map { (it * 3600 / BUCKET).round }
  end

  # Adds the energy of a part of the profile to the buckets it falls into.
  # The first bucket starts at the epoch second `start`.
  def spread_wh(energies, start, from, to, energy)
    step = BUCKET.to_i

    (((from.to_i - start) / step)..((to.to_i - 1 - start) / step)).each do |index|
      next unless index.between?(0, energies.size - 1)

      bucket_from = start + (index * step)
      energies[index] += energy * ([to.to_f, bucket_from + step].min - [from.to_f, bucket_from].max) / (to - from)
    end
  end

  # The buckets of the day up to now. Like in InfluxDB, the last bucket ends
  # with the day.
  def day_grid
    count = ((timeframe.ending - timeframe.beginning) / BUCKET).ceil
    (1..count).map { [timeframe.beginning + (it * BUCKET), timeframe.ending].min }.select { it <= Time.current }.map { timestamp_to_ms(it) }
  end

  # The offsite sessions of the selected cars that reach into the day. The
  # live view shows none. A session without an end belongs to its day alone.
  def offsite_sessions
    @offsite_sessions ||=
      if timeframe.day?
        ChargingSession
          .offsite
          .effective
          .includes(:car)
          .where(car_id: cars.map(&:id))
          .where(started_at: ..timeframe.ending)
          .where('COALESCE(ended_at, started_at) >= ?', timeframe.beginning)
          .to_a
      else
        []
      end
  end
end
