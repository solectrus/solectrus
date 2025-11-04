class TimeframeSelect::MonthPicker::Component < ViewComponent::Base
  def initialize(min_date:, value: nil, name: 'month')
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
    # Only parse if value looks like YYYY-MM format
    return Date.parse("#{value}-01").year if valid_value?
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

  private

  def valid_value?
    value&.match?(/^\d{4}-\d{2}$/)
  end
end
