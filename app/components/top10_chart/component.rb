class Top10Chart::Component < ViewComponent::Base
  def initialize(field, timeframe)
    super
    @field = field
    @timeframe = timeframe
  end
  attr_accessor :field, :timeframe

  def top10
    @top10 ||= PowerTop10.new(fields: [ field ], measurements: [ 'SENEC' ])
  end

  def top10_for_timeframe
    @top10_for_timeframe ||= case timeframe
                             when 'day'   then top10.days
                             when 'month' then top10.months
                             when 'year'  then top10.years
    end
  end

  def maximum
    @maximum ||= top10_for_timeframe.map(&:second).max
  end

  def percent(record)
    (100 * record.second / maximum).round(1)
  end

  def bar_classes
    if field.in?(%w[inverter_power grid_power_minus bat_power_plus])
      'from-green-500 to-green-300 text-green-800'
    else
      'from-red-500 to-red-300 text-red-800'
    end
  end

  def link_to_timestamp(record)
    root_path(
      timeframe: timeframe,
      field: field,
      timestamp: corresponding_date(record.first)
    )
  end

  def corresponding_month(value)
    [
      Rails.configuration.x.installation_date.beginning_of_month,
      value.beginning_of_month
    ].max
  end

  def corresponding_year(value)
    [
      Rails.configuration.x.installation_date.beginning_of_year,
      value.beginning_of_year
    ].max
  end

  def corresponding_date(value)
    case timeframe
    when 'day'   then value
    when 'month' then corresponding_month(value)
    when 'year'  then corresponding_year(value)
    end
  end

  def formatted_date(value)
    case timeframe
    when 'day'   then l(value, format: :default)
    when 'month' then l(value, format: :month)
    when 'year'  then value.year.to_s
    end
  end
end
