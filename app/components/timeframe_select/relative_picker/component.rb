class TimeframeSelect::RelativePicker::Component < ViewComponent::Base
  def initialize(timeframe:, min_date: nil)
    super()
    @timeframe = timeframe
    @min_date = min_date
  end

  attr_reader :timeframe, :min_date

  OPTION_DEFINITIONS = [
    { value: 'P24H', label_key: '.last_24_hours', group: :hours },
    { value: 'P48H', label_key: '.last_48_hours', group: :hours, threshold: -> { 2.days.ago.to_date } },
    { value: 'P72H', label_key: '.last_72_hours', group: :hours, threshold: -> { 3.days.ago.to_date } },
    { value: 'P7D', label_key: '.last_7_days', group: :days, threshold: -> { 7.days.ago.to_date } },
    { value: 'P30D', label_key: '.last_30_days', group: :days, threshold: -> { 30.days.ago.to_date } },
    { value: 'P90D', label_key: '.last_90_days', group: :days, threshold: -> { 90.days.ago.to_date } },
    { value: 'P365D', label_key: '.last_365_days', group: :days, threshold: -> { 365.days.ago.to_date } },
    { value: 'P12M', label_key: '.last_12_months', group: :months, threshold: -> { 12.months.ago.to_date } },
  ].freeze
  private_constant :OPTION_DEFINITIONS

  KNOWN_VALUES = OPTION_DEFINITIONS.to_set { it[:value] }.freeze
  private_constant :KNOWN_VALUES

  GROUPED_DEFINITIONS = OPTION_DEFINITIONS.group_by { it[:group] }.freeze
  private_constant :GROUPED_DEFINITIONS

  BASE_CLASSES = 'flex-1 whitespace-nowrap px-4 py-2.5 rounded-lg text-sm font-medium text-center ' \
                 'focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer transition-colors'.freeze
  SELECTED_BUTTON_CLASSES = "#{BASE_CLASSES} bg-indigo-600 text-white hover:bg-indigo-700 dark:hover:bg-indigo-700".freeze
  UNSELECTED_BUTTON_CLASSES = "#{BASE_CLASSES} bg-gray-100 dark:bg-gray-700 text-gray-900 dark:text-white hover:bg-indigo-100 dark:hover:bg-indigo-900".freeze
  private_constant :BASE_CLASSES, :SELECTED_BUTTON_CLASSES, :UNSELECTED_BUTTON_CLASSES

  def value
    return @value if defined?(@value)

    timeframe_str = timeframe.to_s

    @value =
      if KNOWN_VALUES.include?(timeframe_str) ||
           timeframe_str == installation_timeframe_value
        timeframe_str
      end
  end

  def grouped_options
    groups = []

    GROUPED_DEFINITIONS
      .each do |group_key, definitions|
        options = build_options(definitions)
        next if options.empty?

        if group_key == :months && installation_timeframe_value
          options << {
            value: installation_timeframe_value,
            label:
              t('.since_installation', months: months_since_installation),
          }
        end

        groups << { heading: t(".#{group_key}"), options: }
      end

    groups
  end

  def option_classes(option_value)
    value.to_s == option_value ? SELECTED_BUTTON_CLASSES : UNSELECTED_BUTTON_CLASSES
  end

  private

  def build_options(definitions)
    definitions.filter_map do |tf|
      next unless timeframe_available?(tf)

      { value: tf[:value], label: t(tf[:label_key]) }
    end
  end

  def timeframe_available?(definition)
    return true unless min_date

    threshold = definition[:threshold]
    return true unless threshold

    min_date <= threshold.call
  end

  def months_since_installation
    return @months_since_installation if defined?(@months_since_installation)

    @months_since_installation =
      if min_date
        months =
          ((Date.current.year - min_date.year) * 12) +
            (Date.current.month - min_date.month)
        [months, 99].min
      end
  end

  def installation_timeframe_value
    return @installation_timeframe_value if defined?(@installation_timeframe_value)

    @installation_timeframe_value = months_since_installation ? "P#{months_since_installation}M" : nil
  end
end
