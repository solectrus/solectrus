class TimeframeSelect::WeekPicker::Component < ViewComponent::Base
  def initialize(min_date:, value: nil, name: 'week')
    super()
    @value = value
    @min_date = min_date
    @name = name
  end

  attr_reader :value, :min_date, :name

  def button_id
    "#{name}-button"
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

    # Use I18n for "KW" translation
    "#{t('.week_abbr', default: 'KW')} #{parsed_date.cweek.to_s.rjust(2, '0')}, #{parsed_date.cwyear}"
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
