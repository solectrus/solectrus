class TimeframeSelect::WeekPicker::Component < ViewComponent::Base
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

  private

  def valid_value?
    value&.match?(/^\d{4}-W\d{2}$/)
  end

  def parsed_date
    # Parse ISO week date format (YYYY-Wnn) - Monday of the week
    Date.strptime("#{value}-1", '%G-W%V-%u')
  end
end
