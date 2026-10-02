class TimeframeSelect::Component < ViewComponent::Base
  # Shared CSS classes for form elements
  LABEL_CLASSES = 'text-sm font-medium text-gray-700 dark:text-gray-300'.freeze
  INPUT_CLASSES = 'w-full px-4 py-2.5 text-base border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 appearance-none cursor-pointer transition-colors hover:border-gray-400 dark:hover:border-gray-500'.freeze
  BACK_BUTTON_CLASSES = 'absolute left-4 top-1/2 -translate-y-1/2 flex items-center gap-2 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-600 rounded-lg px-3 py-1.5 focus:outline-none focus:ring-2 focus:ring-gray-400 cursor-pointer transition-colors uppercase text-xs tracking-wider'.freeze

  public_constant :LABEL_CLASSES, :INPUT_CLASSES, :BACK_BUTTON_CLASSES

  # The selected timeframe goes to the end of `base_url`. `car` is the
  # selected car of the car page or of the list of the charging sessions,
  # which the new address keeps.
  def initialize(timeframe:, base_url:, car: nil)
    super()
    @timeframe = timeframe
    @base_url = base_url
    @car = car
  end

  attr_reader :timeframe, :base_url

  def query
    @car.present? ? "?#{{ car: @car }.to_query}" : ''
  end

  def min_date
    Rails.application.config.x.installation_date
  end
end
