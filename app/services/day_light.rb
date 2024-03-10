class DayLight < Flux::Reader
  def self.active?
    day_light = DayLight.new(Date.current)
    return true unless day_light.sunrise && day_light.sunset

    Time.current > day_light.sunrise && Time.current < day_light.sunset
  end

  def initialize(date)
    super(
      fields: ['watt'],
      measurements: [Rails.configuration.x.influx.measurement_forecast],
    )
    @date = date
  end

  def sunrise
    @sunrise ||= time_range&.first
  end

  def sunset
    @sunset ||= time_range&.last
  end

  private

  def time_range
    @time_range ||=
      begin
        records = raw.filter_map(&:records)

        if records.present?
          times = [
            records.first.first.values['_time'],
            records.last.last.values['_time'],
          ].sort

          times.map { |time| Time.zone.parse(time) }
        end
      end
  end

  def raw
    query <<~QUERY
      data = #{from_bucket}
      |> #{range(start: @date.beginning_of_day, stop: @date.end_of_day)}
      |> #{measurements_filter}
      |> #{fields_filter}

      firstValue = data |> first()
      lastValue = data |> last()

      union(tables: [firstValue, lastValue])
    QUERY
  end

  def default_cache_options
    { expires_in: 2.hours }
  end
end
