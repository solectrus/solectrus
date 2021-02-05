module ApplicationHelper
  def title
    case timeframe
    when 'now'   then 'Live'
    when 'day'   then l(timestamp.to_date, format: :default)
    when 'week'  then "KW #{timestamp.to_date.cweek}, #{timestamp.to_date.year}"
    when 'month' then l(timestamp.to_date, format: :month)
    when 'year'  then timestamp.to_date.year.to_s
    when 'all'   then 'Seit Installation'
    end
  end
end
