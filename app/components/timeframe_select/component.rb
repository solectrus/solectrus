class TimeframeSelect::Component < ViewComponent::Base
  # Shared CSS classes for form elements
  LABEL_CLASSES = 'text-sm font-medium text-gray-700 dark:text-gray-300'.freeze
  INPUT_CLASSES = 'w-full px-4 py-2.5 text-base border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 appearance-none cursor-pointer transition-colors hover:border-gray-400 dark:hover:border-gray-500'.freeze

  public_constant :LABEL_CLASSES, :INPUT_CLASSES

  def initialize(timeframe:, sensor_name:, controller_namespace:, chart_name: nil)
    super()
    @timeframe = timeframe
    @sensor_name = sensor_name
    @controller_namespace = controller_namespace
    @chart_name = chart_name
  end

  attr_reader :timeframe, :sensor_name, :controller_namespace, :chart_name

  def base_url
    if controller_namespace == 'balance'
      "/#{sensor_name}"
    else
      "/#{controller_namespace}/#{sensor_name}"
    end
  end

  def min_date
    Rails.application.config.x.installation_date
  end
end
