class Insights::HeatmapAllTime < Insights::HeatmapBase
  private

  def valid_timeframe?
    timeframe.all?
  end

  def build_data
    # Get monthly data
    monthly_data = fetch_data

    # Group by year
    years = monthly_data.group_by { it[:year] }

    # Build the heatmap structure
    heatmap = {}
    years.each do |year, months|
      heatmap[year] = {}
      months.each do |month_data|
        month = month_data[:month]
        value = month_data[:value]

        heatmap[year][month] = value
      end
    end

    heatmap
  end

  def grouping_expressions
    ['EXTRACT(YEAR FROM date)', 'EXTRACT(MONTH FROM date)']
  end

  def date_dimensions
    %i[year month]
  end
end
