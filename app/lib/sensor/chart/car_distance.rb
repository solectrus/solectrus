# The distance of the selected cars, each car in a part of its own. A day
# draws the distance since midnight as a line, from the odometer in InfluxDB.
# A longer timeframe takes the distance from the daily summaries, so a column
# is a day at least.
class Sensor::Chart::CarDistance < Sensor::Chart::Base
  include Sensor::Chart::Concerns::SelectedCars

  def self.supports?(timeframe)
    timeframe.day? || !timeframe.short?
  end

  # `admin` gives the places of the cars in the tooltip of a day, which only
  # the admin sees
  def initialize(admin: false, **)
    super(**)
    @admin = admin
  end

  # Only a car with an odometer has a distance
  def supported?
    super && cars.any? { it.sensor?(:car_odometer) }
  end

  # A day reads InfluxDB directly, so it leaves out a car outside its period
  # of use. A longer timeframe reads the daily values, which hold no value
  # outside it (see Sensor::Summarizer).
  def chart_sensor_names
    @chart_sensor_names ||=
      cars
      .select { !timeframe.day? || it.active_on?(timeframe.date) }
      .select { it.sensor?(:car_odometer) }
      .map { it.sensor_name(:car_odometer) }
  end

  # The label of each part names its car
  def label
    I18n.t('sensors.car_distance')
  end

  private

  # A timeframe without a car in use has no distance
  def build_data
    super if chart_sensor_names.any?
  end

  # Several cars tint each part with the color of their car. The columns of
  # the cars stack. A day draws a line of each car on its own, with its place
  # at each time in the tooltip.
  def build_dataset(sensor_name, chart_data)
    car_number = Sensor::Registry[sensor_name].car_number
    tint_color = cars.find { it.id == car_number }&.display_color if cars.many?
    parts = timeframe.day? ? place_notes(car_number, chart_data) : { stack: 'CarDistance', summed: true }

    super.merge(label: Car.display_name_of(car_number), tintColor: tint_color, **parts).compact
  end

  # The place of the car at each point of the line, from its visits of the
  # day (see Place::VisitDetection). A point between two visits has no note.
  # A day without a visit, like a car without positions, has no notes, and a
  # guest gets none.
  def place_notes(car_number, chart_data)
    return {} unless @admin

    visits = PlaceVisit.where(car_id: car_number, date: timeframe.date).preload(:place, :car).to_a
    return {} if visits.empty?

    # The visit of the build may end before now while the car is still there
    PlaceVisit.mark_ongoing(visits) if timeframe.today?

    notes = chart_data[:labels].zip(chart_data[:data]).map do |label, value|
      place_at(visits, Time.zone.at(label / 1000)) unless value.nil?
    end
    icons = notes.filter_map { it&.dig(:icon) }.uniq

    { tooltipRowNotes: notes, tooltipIcons: icons.index_with { ApplicationController.helpers.icon(it) } }
  end

  # The note of a place, with the icon of its kind: the home or another place
  def place_at(visits, time)
    visit = visits.find { it.started_at < time && (it.ongoing? || it.ended_at >= time) }
    return unless visit

    place = visit.place
    { text: place.display_name || I18n.t('car_breakdown.unknown_place'), icon: place.home? ? 'house' : 'location-dot' }
  end

  # A day shows the odometer minus its reading at midnight, the last reading
  # before it like the daily summary (see DailyDiffs). The odometer is a
  # state, so the line starts at 0 and holds each reading until the next one
  # (see #holds_value?). It ends at the distance of the day.
  #
  # Without a reading at a midnight, for example on the installation date,
  # the day has no distance, like its summary. The line then stays empty and
  # never shows the odometer itself.
  def transform_data(data, sensor_name)
    return super unless timeframe.day? && data.any?

    bounds = day_bounds[sensor_name]
    super(bounds&.all? ? distances(data, *bounds) : Array.new(data.size), sensor_name)
  end

  # The distance since midnight of each reading, from 0 to the distance of
  # the day. A reading outside is wrong, for example a 0 of an offline car
  # (see Sensor::MeterReadings), so the line skips it.
  def distances(data, start_value, end_value)
    total = end_value - start_value

    data.map { it && (it - start_value).then { |distance| distance if distance.between?(0, total) } }.tap do |result|
      result[0] ||= 0
    end
  end

  # { sensor_name => [start_value, end_value] }
  def day_bounds
    return {} unless timeframe.day?

    @day_bounds ||=
      Sensor::Query::Helpers::Influx::DailyDiffs
        .new([timeframe.date], chart_sensor_names, cache: true)
        .bounds
        .fetch(timeframe.date, {})
  end
end
