class Top10Chart::Component < ViewComponent::Base
  def initialize(field:, period:)
    super
    @field = field
    @period = period
  end
  attr_accessor :field, :period

  def top10
    @top10 ||= PowerTop10.new(fields: [field], measurements: ['SENEC'])
  end

  def top10_for_period
    @top10_for_period ||=
      case period
      when 'day'
        top10.days
      when 'month'
        top10.months
      when 'year'
        top10.years
      end
  end

  def maximum
    @maximum ||= top10_for_period.pluck(:value).max
  end

  def percent(record)
    (100 * record[:value] / maximum).round(1)
  end

  def text_classes(record)
    if corresponding_date(record[:date]) == corresponding_date(Date.current)
      'text-yellow-700'
    else
      'text-gray-700'
    end
  end

  def bar_classes
    if field.in?(%w[inverter_power grid_power_minus bat_power_plus])
      'from-green-500 to-green-300 text-green-800'
    else
      'from-red-500 to-red-300 text-red-800'
    end
  end

  def value_classes(record)
    if percent(record) < 5
      'hidden'
    elsif percent(record) < 12
      'hidden xl:inline'
    elsif percent(record) < 40
      'hidden sm:inline'
    end
  end

  def link_to_timestamp(record)
    root_path(period:, field:, timestamp: corresponding_date(record[:date]))
  end

  def corresponding_month(value)
    [
      Rails.configuration.x.installation_date.beginning_of_month,
      value.beginning_of_month,
    ].max
  end

  def corresponding_year(value)
    [
      Rails.configuration.x.installation_date.beginning_of_year,
      value.beginning_of_year,
    ].max
  end

  def corresponding_date(value)
    case period
    when 'day'
      value
    when 'month'
      corresponding_month(value)
    when 'year'
      corresponding_year(value)
    end
  end

  def formatted_date(value)
    case period
    when 'day'
      l(value, format: :default)
    when 'month'
      l(value, format: :month)
    when 'year'
      value.year.to_s
    end
  end
end
