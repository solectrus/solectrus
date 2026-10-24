class Timeframe::Select::RelativePicker::Component < ViewComponent::Base
  # Without `hours`, the group of the hours is left out
  def initialize(timeframe:, min_date: nil, hours: true)
    super()
    @timeframe = timeframe
    @min_date = min_date
    @hours = hours
  end

  attr_reader :timeframe, :min_date, :hours

  OPTION_DEFINITIONS = [
    { value: 'P24H', label_key: '.last_24_hours', group: :hours },
    { value: 'P48H', label_key: '.last_48_hours', group: :hours, threshold: -> { 2.days.ago.to_date } },
    { value: 'P72H', label_key: '.last_72_hours', group: :hours, threshold: -> { 3.days.ago.to_date } },
    { value: 'P7D', label_key: '.last_7_days', group: :days, threshold: -> { 7.days.ago.to_date } },
    { value: 'P30D', label_key: '.last_30_days', group: :days, threshold: -> { 30.days.ago.to_date } },
    { value: 'P90D', label_key: '.last_90_days', group: :days, threshold: -> { 90.days.ago.to_date } },
    { value: 'P365D', label_key: '.last_365_days', group: :days, threshold: -> { 365.days.ago.to_date } },
    { value: 'P12M', label_key: '.last_12_months', group: :months, threshold: -> { 12.months.ago.to_date } },
    { value: 'all', label_key: '.last_all', group: :all },
  ].freeze
  private_constant :OPTION_DEFINITIONS

  KNOWN_VALUES = OPTION_DEFINITIONS.to_set { it[:value] }.freeze
  private_constant :KNOWN_VALUES

  GROUPED_DEFINITIONS = OPTION_DEFINITIONS.group_by { it[:group] }.freeze
  private_constant :GROUPED_DEFINITIONS

  BASE_CLASSES = 'flex-1 whitespace-nowrap px-4 py-2 rounded-lg text-sm font-medium text-center ' \
                 'focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer transition-colors'.freeze
  SELECTED_BUTTON_CLASSES = "#{BASE_CLASSES} #{Timeframe::Select::Component::SELECTED_COLORS}".freeze
  UNSELECTED_BUTTON_CLASSES = "#{BASE_CLASSES} #{Timeframe::Select::Component::UNSELECTED_COLORS}".freeze
  private_constant :BASE_CLASSES
  public_constant :SELECTED_BUTTON_CLASSES, :UNSELECTED_BUTTON_CLASSES

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
    grouped_options_by_key.map do |group_key, options|
      { heading: t(".#{group_key}", default: nil), options: }
    end
  end

  def option_classes(option_value)
    value.to_s == option_value ? SELECTED_BUTTON_CLASSES : UNSELECTED_BUTTON_CLASSES
  end

  # A phone has no room for a heading per group. It shows the windows that
  # count back from now in one grid, each with its unit, and the whole time
  # apart: in years and in months, named as in the menu of the wide screen.
  def recent_options
    grouped_options_by_key.except(:all).flat_map do |group_key, options|
      options
        .reject { it[:value] == installation_timeframe_value }
        .map { it.merge(unit: t(".unit_#{group_key}")) }
    end
  end

  def whole_options
    [
      ({ value: 'all', label: t('data.all_years') } if grouped_options_by_key.key?(:all)),
      ({ value: installation_timeframe_value, label: t('data.all_months') } if installation_timeframe_value),
    ].compact
  end

  def compact_option_classes(option_value)
    [
      COMPACT_CLASSES,
      value.to_s == option_value ? Timeframe::Select::Component::SELECTED_COLORS : Timeframe::Select::Component::UNSELECTED_COLORS,
    ]
  end

  COMPACT_CLASSES = 'truncate px-1 max-lg:px-0.5 py-2 max-lg:py-3 rounded-lg text-sm max-lg:text-subhead max-lg:leading-6 text-center ' \
                    'focus:outline-none focus:ring-2 focus:ring-indigo-500 cursor-pointer transition-colors'.freeze
  public_constant :COMPACT_CLASSES

  private

  def grouped_options_by_key
    @grouped_options_by_key ||=
      GROUPED_DEFINITIONS
        .filter_map do |group_key, definitions|
          next if group_key == :hours && !hours

          options = build_options(definitions)
          [group_key, with_installation(group_key, options)] if options.any?
        end
        .to_h
  end

  def with_installation(group_key, options)
    return options unless group_key == :months && installation_timeframe_value

    [*options, { value: installation_timeframe_value, label: t('.since_installation', months: months_since_installation) }]
  end

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
