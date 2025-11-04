class TimeframeSelect::YearPicker::Component < ViewComponent::Base
  def initialize(min_date:, value: nil, name: 'year')
    super()
    @value = value
    @min_date = min_date
    @name = name
  end

  attr_reader :value, :min_date, :name

  def min_year
    min_date.year
  end

  def max_year
    Date.current.year
  end
end
