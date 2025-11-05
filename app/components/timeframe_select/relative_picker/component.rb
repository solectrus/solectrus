class TimeframeSelect::RelativePicker::Component < ViewComponent::Base
  def initialize(timeframe:, name: 'relative-picker-input', min_date: nil)
    super()
    @timeframe = timeframe
    @name = name
    @min_date = min_date
  end

  attr_reader :timeframe, :name, :min_date

  def button_id
    "#{name}-button"
  end

  def value
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
    opts = []

    if timeframe_available?('P24H')
      opts << { value: 'P24H', label: t('.last_24_hours').html_safe }
    end
    if timeframe_available?('P7D')
      opts << { value: 'P7D', label: t('.last_7_days').html_safe }
    end
    if timeframe_available?('P30D')
      opts << { value: 'P30D', label: t('.last_30_days').html_safe }
    end
    if timeframe_available?('P90D')
      opts << { value: 'P90D', label: t('.last_90_days').html_safe }
    end
    if timeframe_available?('P12M')
      opts << { value: 'P12M', label: t('.last_12_months').html_safe }
    end

    if installation_timeframe_value
      opts << {
        value: installation_timeframe_value,
        label:
          t('.since_installation', months: months_since_installation).html_safe,
      }
    end

    opts
  end

  private

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

  def installation_timeframe_value
    months_since_installation ? "P#{months_since_installation}M" : nil
  end
end
