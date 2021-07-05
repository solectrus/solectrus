module ApplicationHelper
  def title
    case timeframe
    when 'now'
      'Live'
    when 'day'
      l(timestamp, format: :default)
    when 'week'
      "KW #{timestamp.cweek}, #{timestamp.year}"
    when 'month'
      l(timestamp, format: :month)
    when 'year'
      timestamp.year.to_s
    when 'all'
      'Seit Installation'
    end
  end
end
