class PowerSum < Flux::Reader
  def now
    last('-5m')
  end

  def day(start)
    sum start: start.beginning_of_day, stop: start.end_of_day
  end

  def week(start)
    sum start: start.beginning_of_week.beginning_of_day,
        stop: start.end_of_week.end_of_day
  end

  def month(start)
    sum start: start.beginning_of_month.beginning_of_day,
        stop: start.end_of_month.end_of_day
  end

  def year(start)
    sum start: start.beginning_of_year.beginning_of_day,
        stop: start.end_of_year.end_of_day
  end

  def all(start)
    sum start: start
  end

  private

  def last(start)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range(start: start)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> last()
    QUERY

    result
      .values
      .each_with_object(empty_hash) do |table, hash|
        record = table.records.first

        hash[record.values['_field'].to_sym] = record.values['_value']
        hash[:time] ||= Time.zone.parse record.values['_time']
      end
  end

  def sum(start:, stop: nil)
    result = query <<-QUERY
      #{from_bucket}
      |> #{range(start: start, stop: stop)}
      |> #{measurements_filter}
      |> #{fields_filter}
      |> integral(unit:1h)
    QUERY

    result
      .values
      .each_with_object(empty_hash) do |table, hash|
        record = table.records.first

        hash[record.values['_field'].to_sym] = record.values['_value']
        hash[:time] ||= Time.zone.parse record.values['_stop']
      end
  end

  def empty_hash
    result = {}
    fields.each { |field| result[field] = nil }
    result[:time] = nil
    result
  end
end
