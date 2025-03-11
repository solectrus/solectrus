class ChartBase < Flux::Reader
  def grouping_period(timeframe)
    case timeframe.id
    when :days, :week, :month
      :day
    when :year, :months
      :month
    when :all
      :year
    end
  end

  def dates(timeframe)
    case grouping_period(timeframe)
    when :day
      days_from(timeframe)
    when :month
      months_from(timeframe)
    when :year
      years_from(timeframe)
    end
  end

  private

  def days_from(timeframe)
    timeframe.beginning.to_date..timeframe.ending.to_date
  end

  def months_from(timeframe)
    (timeframe.beginning.to_date..timeframe.ending.to_date).select do |date|
      date.day == 1
    end
  end

  def years_from(timeframe)
    (timeframe.beginning.year..timeframe.ending.year).map do |year|
      Date.new(year, 1, 1)
    end
  end
end
