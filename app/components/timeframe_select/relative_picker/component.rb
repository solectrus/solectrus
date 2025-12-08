class TimeframeSelect::RelativePicker::Component < ViewComponent::Base
  def initialize(timeframe:, name: 'relative-picker-input', min_date: nil)
    super()
    @timeframe = timeframe
    @name = name
    @min_date = min_date
  end

  attr_reader :timeframe, :name, :min_date

  DURATION_THRESHOLDS = {
    'P72H' => -> { 3.days.ago.to_date },
    'P7D' => -> { 7.days.ago.to_date },
    'P30D' => -> { 30.days.ago.to_date },
    'P90D' => -> { 90.days.ago.to_date },
    'P365D' => -> { 365.days.ago.to_date },
    'P12M' => -> { 12.months.ago.to_date },
  }.freeze
  private_constant :DURATION_THRESHOLDS

  def button_id
    "#{name}-button"
  end

  def value
    # Check if current timeframe is a relative/predefined one
    timeframe_str = timeframe.to_s

    # Check against known relative formats
    if %w[P24H P72H P7D P30D P90D P365D P12M].include?(timeframe_str)
      return timeframe_str
    end

    # Check if it matches installation timeframe pattern (PxxM)
    if installation_timeframe_value &&
         timeframe_str == installation_timeframe_value
      return timeframe_str
    end

    nil
  end

  def display_text
    return '&nbsp;'.html_safe if value.blank?

    # Special case for installation timeframe: use short display text
    if installation_timeframe_value && value == installation_timeframe_value
      return t('.since_installation_short', months: months_since_installation)
    end

    option = options.find { |opt| opt[:value] == value }
    return '&nbsp;'.html_safe unless option

    # Remove HTML tags from label for display button
    helpers.strip_tags(option[:label])
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

  def options
    timeframes = [
      { value: 'P24H', label_key: '.last_24_hours' },
      { value: 'P72H', label_key: '.last_72_hours' },
      { value: 'P7D', label_key: '.last_7_days' },
      { value: 'P30D', label_key: '.last_30_days' },
      { value: 'P90D', label_key: '.last_90_days' },
      { value: 'P365D', label_key: '.last_365_days' },
      { value: 'P12M', label_key: '.last_12_months' },
    ]

    opts =
      timeframes.filter_map do |tf|
        next unless timeframe_available?(tf[:value])

        { value: tf[:value], label: t(tf[:label_key]) }
      end

    if installation_timeframe_value
      opts << {
        value: installation_timeframe_value,
        label: t('.since_installation', months: months_since_installation),
      }
    end

    opts
  end

  private

  def timeframe_available?(duration_string)
    return true unless min_date

    threshold = DURATION_THRESHOLDS[duration_string]
    return true unless threshold

    min_date <= threshold.call
  end

  def installation_timeframe_value
    months_since_installation ? "P#{months_since_installation}M" : nil
  end
end
