class Top10Chart::Component < ViewComponent::Base
  def initialize(field:, period:, sort:, calc:)
    raise ArgumentError, 'field must be present' if field.blank?
    raise ArgumentError, 'period must be present' if period.blank?
    raise ArgumentError, 'sort must be present' if sort.blank?
    raise ArgumentError, 'calc must be present' if calc.blank?

    super
    @field = field
    @period = period
    @sort = sort
    @calc = ActiveSupport::StringInquirer.new(calc)
  end
  attr_accessor :field, :period, :sort, :calc

  def top10
    @top10 ||=
      PowerTop10.new(
        field:,
        measurements: [Rails.configuration.x.influx.measurement_pv],
        calc:,
        desc: sort.desc?,
      )
  end

  def top10_for_period
    @top10_for_period ||=
      case period
      when 'day'
        top10.days
      when 'week'
        top10.weeks
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

  # CSS classes to HIDE the value inside the bar when the bar is too small
  def value_classes_inside(record)
    case percent(record)
    when ..5
      'hidden'
    when 5..10
      'hidden xl:inline'
    when 10..20
      'hidden lg:inline'
    when 20..40
      'hidden md:inline'
    when 40..50
      'hidden sm:inline'
    else
      'inline'
    end
  end

  # CSS classes to SHOW the value outside the bar when the bar is too small
  def value_classes_outside(record)
    case percent(record)
    when ..5
      'inline'
    when 5..10
      'inline xl:hidden'
    when 10..20
      'inline lg:hidden'
    when 20..40
      'inline md:hidden'
    when 40..50
      'inline sm:hidden'
    else
      'hidden'
    end
  end

  def timeframe_path(record)
    root_path(
      field: field.gsub(/_plus|_minus/, ''),
      timeframe: corresponding_date(record[:date]),
    )
  end

  def corresponding_week(value)
    [
      Rails.configuration.x.installation_date.beginning_of_week,
      value.beginning_of_week,
    ].max
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
    when 'week'
      corresponding_week(value).strftime('%Y-W%W')
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
    when 'week'
      l(value, format: :week)
    when 'month'
      l(value, format: :month)
    when 'year'
      value.year.to_s
    end
  end

  def note
    result = []
    result << t('.note_max') if calc.max?
    result << t('.note_sum') if calc.sum?
    result << t('.note_asc') if sort.asc?
    safe_join(result, '. ')
  end
end
