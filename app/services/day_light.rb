class DayLight < Flux::Reader
  def self.active?
    # Assume sun is shining if forecast is not available
    return true unless SensorConfig.x.exists?(:inverter_power_forecast)

    day_light = new(Date.current)

    # Same as above if sunrise or sunset is unavailable
    return true unless day_light.sunrise && day_light.sunset

    # Sun is shining when we are between sunrise and sunset
    day_light.sunrise.past? && day_light.sunset.future?
  end

  def initialize(date)
    super(sensors: [:inverter_power_forecast])
    @date = date
  end

  def sunrise
    time_range&.first
  end

  def sunset
    time_range&.last
  end

  private

  def time_range
    @time_range ||=
      begin
        records = raw.filter_map(&:records).flatten
        times = records.map { |record| Time.zone.parse(record.values['_time']) }
        times.sort
      end
  end

  def raw
    Rails
      .cache
      .fetch("day_light_time_range_#{@date}", expires_in: 24.hours) do
        query <<~QUERY
          data = #{from_bucket}
          |> #{range(start: @date.beginning_of_day, stop: @date.end_of_day)}
          |> #{filter}
          |> filter(fn: (r) => r["_value"] > 0)

          firstValue = data |> first()
          lastValue = data |> last()

          union(tables: [firstValue, lastValue])
        QUERY
      end
  end
end
