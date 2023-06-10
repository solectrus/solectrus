class PowerTop10 < Flux::Reader
  def initialize(field:, measurements:, desc:)
    super(fields: [field], measurements:)
    @desc = desc
    @field = field
  end

  attr_reader :field, :desc

  def days
    top start: start(:day), stop: stop(:day), window: '1d'
  end

  def months
    top start: start(:month), stop: stop(:month), window: '1mo'
  end

  def years
    top start: start(:year), stop: stop(:year), window: '1y'
  end

  private

  def start(period)
    raw = Rails.configuration.x.installation_date.beginning_of_day
    # In ascending order, the first period may not be included because it is (most likely) not complete
    adjustment = desc ? 0 : 1.public_send(period)

    (raw + adjustment).public_send("beginning_of_#{period}")
  end

  def stop(period)
    raw = Date.current.end_of_day
    # In ascending order, the current period may not be included because it is not yet complete
    adjustment = desc ? 0 : 1.public_send(period)

    (raw - adjustment).public_send("end_of_#{period}")
  end

  def top(start:, stop:, window:, limit: 10)
    return [] if start > stop

    raw = query(build_query(start:, stop:, window:, limit:))
    return [] unless raw[0]

    raw[0].records.map do |record|
      time = Time.zone.parse(record.values['_time']).utc - 1.second
      value = record.values['_value']

      { date: time.to_date, value: }
    end
  end

  def default_cache_options
    { expires_in: 10.minutes }
  end

  def build_query(start:, stop:, window:, limit:)
    <<-QUERY
      import "timezone"

      #{from_bucket}
        |> #{range(start:, stop:)}
        |> #{measurements_filter}
        |> #{fields_filter}
        |> aggregateWindow(every: 1h, fn: mean)
        |> aggregateWindow(every: #{window}, fn: sum, location: #{location})
        |> filter(fn: (r) => r._value > 0)
        |> sort(columns: ["_value"], desc: #{desc})
        |> limit(n: #{limit})
    QUERY
  end
end
