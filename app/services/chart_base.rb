class ChartBase < Flux::Reader
  def grouping_period(timeframe)
    case timeframe.id
    when :week, :month
      :day
    when :year
      :month
    when :all
      :year
    end
  end

  def dates(timeframe)
    case timeframe.id
    when :week, :month
      (timeframe.beginning.to_date..timeframe.ending.to_date).to_a
    when :year
      year = timeframe.beginning.year
      (1..12).map { |month| Date.new(year, month, 1) }
    when :all
      (timeframe.beginning.year..timeframe.ending.year).map do |year|
        Date.new(year, 1, 1)
      end
    end
  end
end
