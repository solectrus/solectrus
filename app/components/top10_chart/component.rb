class Top10Chart::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(sensor:, period:, sort:, calc:)
    raise ArgumentError, 'sensor must be present' if sensor.blank?
    raise ArgumentError, 'period must be present' if period.blank?
    raise ArgumentError, 'sort must be present' if sort.blank?
    raise ArgumentError, 'calc must be present' if calc.blank?

    super
    @sensor = sensor
    @period = period
    @sort = sort
    @calc = ActiveSupport::StringInquirer.new(calc)
  end
  attr_accessor :sensor, :period, :sort, :calc

  def top10
    @top10 ||= PowerTop10.new(sensor:, calc:, desc: sort.desc?)
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
      'text-yellow-700 dark:text-yellow-300'
    else
      'text-gray-700 dark:text-gray-400'
    end
  end

  def bar_classes # rubocop:disable Metrics/CyclomaticComplexity
    case sensor.to_sym
    when :grid_export_power, :inverter_power
      'from-green-500 to-green-300 text-green-800 dark:from-green-700 dark:to-green-500 dark:text-green-900'
    when :battery_discharging_power, :battery_charging_power
      'from-green-700 to-green-300 text-green-800 dark:from-green-800 dark:to-green-500 dark:text-green-900'
    when :house_power, :car_driving_distance
      'from-slate-500 to-slate-300 text-slate-800 dark:from-slate-700 dark:to-slate-500 dark:text-slate-900'
    when :wallbox_power
      'from-slate-600 to-slate-300 text-slate-800 dark:from-slate-700 dark:to-slate-500 dark:text-slate-900'
    when :heatpump_power
      'from-slate-700 to-slate-300 text-slate-800 dark:from-slate-800 dark:to-slate-500 dark:text-slate-900'
    when :grid_import_power, :case_temp
      'from-red-600   to-red-300   text-red-800   dark:from-red-800   dark:to-red-400   dark:text-red-900'
    when :heatpump_heating_power
      'from-orange-700 to-orange-300 text-orange-800 dark:from-orange-800 dark:to-orange-400 dark:text-orange-900'
    when :outdoor_temp
      'from-teal-700 to-teal-300 text-teal-800 dark:from-teal-800 dark:to-teal-400 dark:text-teal-900'
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
      sensor: sensor.to_s.sub(/_import|_export|_charging|_discharging/, ''),
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

  def unit_method
    case sensor.to_sym
    when :case_temp, :outdoor_temp
      :to_grad_celsius
    when :car_driving_distance
      :to_km
    else
      calc.max? ? :to_watt : :to_watt_hour
    end
  end
end
