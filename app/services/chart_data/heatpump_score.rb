class ChartData::HeatpumpScore < ChartData::Base
  def options
    {
      plugins: {
        tooltip: {
          enabled: false,
        },
      },
      scales: {
        y: {
          min: 0,
          max: 1,
          display: false,
        },
      },
    }
  end

  def type
    'bar'
  end

  private

  COLORS = {
    1 => '#065f46', # emerald-800
    2 => '#10b981', # emerald-500
    3 => '#fef08a', # yellow-200
    4 => '#fb923c', # orange-400
    5 => '#f87171', # red-400
  }.freeze
  private_constant :COLORS

  def data
    return unless chart

    {
      labels: chart.map(&:first),
      datasets:
        COLORS.map do |value, color|
          {
            label: value.to_s,
            data: chart.filter_map { |p| p.second&.round == value ? 1 : 0 },
            backgroundColor: color,
            barPercentage: 1.0,
            categoryPercentage: 1.0,
          }
        end,
    }
  end

  def chart
    @chart ||=
      AvgChart.new(sensor: :heatpump_score).call(timeframe)[:heatpump_score]
  end
end
