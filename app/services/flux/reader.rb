class Flux::Reader < Flux::Base
  def initialize(sensors:)
    super()

    @sensors = sensors
  end

  def call(timeframe)
    @timeframe = timeframe
  end

  attr_reader :fields, :measurements, :sensors, :timeframe

  private

  WINDOW = {
    now: '30s',
    day: '5m',
    week: '1d',
    month: '1d',
    year: '1mo',
    all: '1y',
  }.freeze
  private_constant :WINDOW

  def from_bucket
    "from(bucket: \"#{influx_bucket}\")"
  end

  def filter(selected_sensors: sensors)
    raw =
      selected_sensors.filter_map do |sensor|
        [
          SensorConfig.x.measurement(sensor),
          SensorConfig.x.field(sensor),
        ].compact.presence
      end

    # Build hash: Key is measurement, value is array of fields
    hash = raw.group_by(&:first).transform_values { |v| v.map(&:last) }

    # Build filter string
    filter =
      hash.map do |measurement, fields|
        field_filter =
          fields.map { |field| "r[\"_field\"] == \"#{field}\"" }.join(' or ')

        "r[\"_measurement\"] == \"#{measurement}\" and (#{field_filter})"
      end

    "filter(fn: (r) => #{filter.join(' or ')})"
  end

  def range(start:, stop: nil)
    start = start&.iso8601
    stop = stop&.iso8601

    stop ? "range(start: #{start}, stop: #{stop})" : "range(start: #{start})"
  end

  def location
    "timezone.location(name: \"#{Rails.application.config.time_zone}\")"
  end

  def query_with_time
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = yield
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    duration = end_time - start_time

    [result, duration]
  end

  def query(string)
    result, duration =
      query_with_time { client.create_query_api.query(query: string) }

    ActiveSupport::Notifications.instrument(
      'query.flux_reader',
      class: self.class.name,
      query: string,
      sensors:,
      duration:,
    )

    result
  end
end
