class TimeframeSelect::YearPicker::Component < ViewComponent::Base
  def initialize(min_date:, timeframe:, name: 'year')
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
    timeframe.effective_ending_date.year
  end

  def selected_value
    value if timeframe.year?
  end

  def min_year
    min_date.year
  end

  def max_year
    Date.current.year
  end
end
