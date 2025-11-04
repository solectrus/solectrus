class TimeframeSelect::Component < ViewComponent::Base
  # Shared CSS classes for form elements
  LABEL_CLASSES = 'text-sm font-medium text-gray-700 dark:text-gray-300'.freeze
  INPUT_CLASSES = 'dropdown-icon w-full px-4 py-2.5 text-base border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 appearance-none cursor-pointer transition-colors hover:border-gray-400 dark:hover:border-gray-500'.freeze

  public_constant :LABEL_CLASSES, :INPUT_CLASSES

  def initialize(timeframe:, sensor_name:, controller_namespace:)
    super()
    @timeframe = timeframe
    @sensor_name = sensor_name
    @controller_namespace = controller_namespace
  end

  attr_reader :timeframe, :sensor_name, :controller_namespace

  def base_url
    helpers.url_for(
      controller: "#{controller_namespace}/home",
      sensor_name:,
      action: 'index',
    )
  end

  def base_path
    if controller_namespace == 'balance'
      "/#{sensor_name}"
    else
      "/#{controller_namespace}/#{sensor_name}"
    end
  end

  def min_date
    Rails.application.config.x.installation_date
  end

  def beginning_date
    timeframe.beginning.to_date
  end

  def ending_date
    timeframe.ending.to_date
  end

  def current_year
    timeframe.year? ? timeframe.to_s : timeframe.corresponding_year
  end

  def current_month
    timeframe.month? ? timeframe.to_s : timeframe.corresponding_month
  end

  def current_week
    timeframe.week? ? timeframe.to_s : timeframe.corresponding_week
  end

  def current_day
    timeframe.day? ? timeframe.to_s : timeframe.corresponding_day
  end

  def current_relative
    # Check if current timeframe is a relative/predefined one
    timeframe_str = timeframe.to_s

    # Check against known relative formats
    return timeframe_str if %w[P24H P7D P30D P90D P12M].include?(timeframe_str)

    # Check if it matches installation timeframe pattern (PxxM)
    if installation_timeframe_value &&
         timeframe_str == installation_timeframe_value
      return timeframe_str
    end

    nil
  end

  def months_since_installation
    return unless min_date

    # Calculate the difference in months from min_date to now
    months =
      ((Date.current.year - min_date.year) * 12) +
        (Date.current.month - min_date.month)

    # Cap at 99 as per timeframe logic
    [months, 99].min
  end

  def installation_timeframe_value
    months = months_since_installation
    months ? "P#{months}M" : nil
  end

  def timeframe_available?(duration_string)
    return true unless min_date

    case duration_string
    when 'P7D'
      min_date <= 7.days.ago.to_date
    when 'P30D'
      min_date <= 30.days.ago.to_date
    when 'P90D'
      min_date <= 90.days.ago.to_date
    when 'P12M'
      min_date <= 12.months.ago.to_date
    else
      true
    end
  end
end
