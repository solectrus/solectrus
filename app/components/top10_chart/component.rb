class Top10Chart::Component < ViewComponent::Base
  def initialize(field:, period:, sort:)
    raise ArgumentError, 'field must be present' if field.blank?
    raise ArgumentError, 'period must be present' if period.blank?

    super
    @field = field
    @period = period
    @sort = sort
  end
  attr_accessor :field, :period, :sort

  def top10
    @top10 ||=
      PowerTop10.new(fields: [field], measurements: ['SENEC'], desc: sort.desc?)
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
    (record[:value] * 100 / maximum).round(1)
  end

  def text_classes(record)
    if corresponding_date(record[:date]) == corresponding_date(Date.current)
      'text-yellow-700'
    else
      'text-gray-700'
    end
  end

  def bar_classes
    case field.to_sym
    when :grid_power_minus, :inverter_power
      'from-green-500 to-green-300 text-green-800'
    when :bat_power_minus, :bat_power_plus
      'from-green-700 to-green-300 text-green-800'
    when :house_power
      'from-slate-500 to-slate-300 text-slate-800'
    when :wallbox_charge_power
      'from-slate-600 to-slate-300 text-slate-800'
    when :grid_power_plus
      'from-red-600 to-red-300 text-red-800'
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

  def timeframe_path(record)
    root_path(
      field: field.gsub(/_plus|_minus/, ''),
      timeframe: corresponding_date(record[:date]),
    )
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
      corresponding_month(value).strftime('%Y-%m')
    when 'year'
      corresponding_year(value).strftime('%Y')
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
