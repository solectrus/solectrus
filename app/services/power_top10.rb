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

    case period
    when :day
      desc ? raw.beginning_of_day : (raw + 1.day).beginning_of_day
    when :month
      desc ? raw.beginning_of_month : (raw + 1.month).beginning_of_month
    when :year
      desc ? raw.beginning_of_year : (raw + 1.year).beginning_of_year
    end
  end

  def stop(period)
    raw = Date.current.end_of_day

    case period
    when :day
      desc ? raw.end_of_day : (raw - 1.day).end_of_day
    when :month
      desc ? raw.end_of_month : (raw - 1.month).end_of_month
    when :year
      desc ? raw.end_of_year : (raw - 1.year).end_of_year
    end
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
