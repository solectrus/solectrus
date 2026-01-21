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
      'text-amber-700 dark:text-amber-300'
    else
      'text-gray-700 dark:text-gray-400'
    end
  end

  def bar_style(record)
    "width: #{percent(record)}%;"
  end

  def bar_classes
    'bar-gradient text-white dark:text-white/80'
  end

  def bar_gradient_bg_classes
    scale = sensor.color_scale
    return sensor.color_background if scale.blank?

    scale.first[:colorClass]
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

  def bar_gradient_class
    sensor.color_scale.present? ? 'top10-gradient' : ''
  end

  def bar_gradient_style(record)
    scale = sensor.color_scale
    return if scale.blank?

    styles = []
    value = record[:value]
    return if value.nil?

    from = gradient_from_color(scale, dark: false)
    to = gradient_to_color(scale, value, dark: false)
    from_dark = gradient_from_color(scale, dark: true)
    to_dark = gradient_to_color(scale, value, dark: true)

    styles << "--top10-gradient-from: #{from}" if from
    styles << "--top10-gradient-to: #{to}" if to
    styles << "--top10-gradient-from-dark: #{from_dark}" if from_dark
    styles << "--top10-gradient-to-dark: #{to_dark}" if to_dark

    styles.join('; ')
  end

  def gradient_color_var(classes, dark:)
    return if classes.blank?

    prefix = dark ? 'dark:bg-' : 'bg-'
    color_class = classes.split.find { |css_class| css_class.start_with?(prefix) }
    return if color_class.blank?

    color_name = color_class.delete_prefix(prefix)
    "var(--color-#{color_name})"
  end

  def gradient_from_color(scale, dark:)
    low = scale.first[:colorClass]
    gradient_color_var(low, dark:) || gradient_color_var(low, dark: false)
  end

  def gradient_to_color(scale, value, dark:)
    stops = gradient_stops(scale, dark:)
    return if stops.empty?

    value = value.to_f

    return stops.first[:color] if value <= stops.first[:value]
    return stops.last[:color] if value >= stops.last[:value]

    lower, upper = gradient_bounds(stops, value)
    mix_gradient_colors(lower, upper, value)
  end

  def gradient_stops(scale, dark:)
    stops = scale.filter_map do |stop|
      classes = stop[:colorClass]
      color = gradient_color_var(classes, dark:) || gradient_color_var(classes, dark: false)
      next if color.blank?

      { value: stop[:value].to_f, color: }
    end
    stops.sort_by { |stop| stop[:value] }
  end

  def gradient_bounds(stops, value)
    lower = stops.first
    upper = stops.last

    stops.each_cons(2) do |left, right|
      next unless value.between?(left[:value], right[:value])

      lower = left
      upper = right
      break
    end

    [lower, upper]
  end

  def mix_gradient_colors(lower, upper, value)
    range = upper[:value] - lower[:value]
    return lower[:color] if range <= 0

    ratio = (value - lower[:value]) / range
    upper_pct = (ratio * 100).round(2)
    lower_pct = (100 - upper_pct).round(2)

    "color-mix(in oklab, #{lower[:color]} #{lower_pct}%, #{upper[:color]} #{upper_pct}%)"
  end

  def timeframe_path(record)
    sensor = Sensor::Registry[sensor_name]

    if sensor.is_a?(Sensor::Definitions::CustomPower)
      house_home_path(
        sensor_name:,
        timeframe: corresponding_date(record[:date]),
      )
    elsif sensor.category == :inverter && Setting.enable_multi_inverter
      inverter_home_path(
        sensor_name:,
        timeframe: corresponding_date(record[:date]),
      )
    elsif sensor.category == :heatpump
      heatpump_home_path(
        sensor_name:,
        timeframe: corresponding_date(record[:date]),
      )
    else
      balance_home_path(
        sensor_name:,
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
