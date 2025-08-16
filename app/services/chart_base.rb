class ChartBase < Flux::Reader
  def grouping_period(timeframe)
    case timeframe.id
    when :days, :week, :month, :range
      :day
    when :year, :months
      :month
    when :years, :all
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
    (
      timeframe.beginning.to_date.beginning_of_month..timeframe.ending.to_date
    ).step(1.month).to_a
  end

  def years_from(timeframe)
    (
      timeframe.beginning.to_date.beginning_of_year..timeframe.ending.to_date
    ).step(1.year).to_a
  end
end
