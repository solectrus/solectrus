class TimeframeSelect::DayPicker::Component < ViewComponent::Base
  def initialize(min_date:, timeframe:, name:, range: false)
    super()
    @timeframe = timeframe
    @min_date = min_date
    @name = name
    @range = range
  end

  attr_reader :timeframe, :min_date, :name, :range

  def max_date
    Date.current
  end

  def button_id
    "#{name}-button"
  end

  def value
    if range
      timeframe.beginning.to_date.to_s
    else
      timeframe.day? ? timeframe.to_s : timeframe.corresponding_day
    end
  end

  def ending_value
    return unless range

    timeframe.ending.to_date.to_s
  end

  def formatted_value
    range ? format_date_range : format_single_date
  end

  private

  def format_single_date
    return if value.blank?

    date = Date.parse(value)
    date.strftime('%d.%m.%Y')
  end

  def format_date_range
    return if value.blank? || ending_value.blank?

    start_date = Date.parse(value)
    end_date = Date.parse(ending_value)
    "#{start_date.strftime('%d.%m.%Y')} - #{end_date.strftime('%d.%m.%Y')}"
  end
end
