class Insights::HeatmapYearly < Insights::HeatmapBase
  private

  def valid_timeframe?
    timeframe.year?
  end

  def build_data
    # Get daily data for the specific year
    daily_data = fetch_data
    year = timeframe.date.year
    heatmap = {}

    daily_data.each do |day_data|
      month = day_data[:month]
      day = day_data[:day]

      # Stop processing if we hit a future month (data is chronologically ordered)
      break if Date.new(year, month, 1).future?

      heatmap[month] ||= {}
      heatmap[month][day] = day_data[:value]
    end

    heatmap
  end

  def grouping_expressions
    ['EXTRACT(MONTH FROM date)', 'EXTRACT(DAY FROM date)']
  end

  def date_dimensions
    %i[month day]
  end
end
