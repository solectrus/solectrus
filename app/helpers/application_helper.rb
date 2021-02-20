module ApplicationHelper
  def title
    case timeframe
    when 'now'   then 'Live'
    when 'day'   then l(timestamp, format: :default)
    when 'week'  then "KW #{timestamp.cweek}, #{timestamp.year}"
    when 'month' then l(timestamp, format: :month)
    when 'year'  then timestamp.year.to_s
    when 'all'   then 'Seit Installation'
    end
  end
end
