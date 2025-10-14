class Top10Chart::Component < ViewComponent::Base # rubocop:disable Metrics/ClassLength
  def initialize(sensor_name:, period:, sort:, calc:)
    raise ArgumentError, 'sensor_name must be present' if sensor_name.blank?
    raise ArgumentError, 'period must be present' if period.blank?
    raise ArgumentError, 'sort must be present' if sort.blank?
    raise ArgumentError, 'calc must be present' if calc.blank?

    super()
    @sensor_name = sensor_name
    @period = period
    @sort = sort
    @calc = ActiveSupport::StringInquirer.new(calc)
  end
  attr_accessor :sensor_name, :period, :sort, :calc

  def sensor
    @sensor ||= Sensor::Registry[sensor_name]
  end

  def top10_for_period
    @top10_for_period ||=
      Sensor::Query::Ranking.new(
        sensor_name,
        aggregation: calc.to_sym,
        period: period.to_sym,
        desc: sort.desc?,
        limit: 10,
      ).call
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

  def bar_style(record)
    "width: #{percent(record)}%; --bar-color: #{sensor.color_hex};"
  end

  def bar_classes
    'bar-gradient text-white dark:text-white/80'
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
    if sensor_name.to_s.match?(/custom_power_\d{2}/)
      house_home_path(
        sensor_name:,
        timeframe: corresponding_date(record[:date]),
      )
    elsif sensor_name.to_s.match?(/inverter_power_\d{1}/)
      inverter_home_path(
        sensor_name:,
        timeframe: corresponding_date(record[:date]),
      )
    elsif sensor_name == :heatpump_heating_power
      heatpump_home_path(
        sensor_name:,
        timeframe: corresponding_date(record[:date]),
      )
    else
      root_path(
        sensor_name:
          sensor_name.to_s.sub(/_import|_export|_charging|_discharging/, ''),
        timeframe: corresponding_date(record[:date]),
      )
    end
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
      corresponding_week(value).strftime('%G-W%V')
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
    result << t('.note_asc') if sort.asc?
    safe_join(result, '. ')
  end

  def context
    if sensor.unit == :watt
      calc.max? ? :rate : :total
    else
      :auto
    end
  end
end
