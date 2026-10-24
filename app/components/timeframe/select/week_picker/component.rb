class Timeframe::Select::WeekPicker::Component < ViewComponent::Base
  def initialize(min_date:, timeframe:, name: 'week')
    super()
    @timeframe = timeframe
    @min_date = min_date
    @name = name
  end

  attr_reader :timeframe, :min_date, :name

  def button_id
    "#{name}-button"
  end

  def value
    timeframe.week? ? timeframe.to_s : timeframe.corresponding_week
  end

  def selected_value
    value if timeframe.week?
  end

  def initial_year
    return parsed_date.cwyear if valid_value?
    return Date.current.year if Date.current >= min_date

    min_date.year
  end

  def min_year
    min_date.year
  end

  def max_year
    Date.current.year
  end

  def max_date
    Date.current
  end

  def formatted_value
    return t('.select_week') unless valid_value?

    I18n.l(parsed_date, format: :week)
  end

  # The tile of a phone names the year only when it is not the current one,
  # as the timeframe row does (see TimeframeSegmentItems)
  def short_formatted_value
    return formatted_value unless valid_value? && parsed_date.cwyear == Date.current.cwyear

    I18n.l(parsed_date, format: :week_of_year)
  end

  private

  def valid_value?
    value&.match?(/^\d{4}-W\d{2}$/)
  end

  def parsed_date
    # Parse ISO week date format (YYYY-Wnn) - Monday of the week
    Date.strptime("#{value}-1", '%G-W%V-%u')
  end
end
