class ChartData::CustomPower < ChartData::Base
  def initialize(timeframe:, sensor:)
    super(timeframe:)
    @sensor = sensor
  end

  attr_reader :sensor

  private

  def data
    {
      labels: chart[chart.keys.first]&.map { |x| x.first.to_i * 1000 },
      datasets:
        chart.map do |chart_sensor, data|
          {
            label: I18n.t("sensors.#{chart_sensor}"),
            data: data.map(&:second),
          }.merge(style)
        end,
    }
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: [sensor]).call(
        timeframe,
        fill: !timeframe.current?,
      )
  end

  def style
    {
      fill: 'origin',
      # Base color, will be changed to gradient in JS
      backgroundColor: '#64748b', # bg-slate-500
      borderWidth: 1,
      borderRadius: 5,
      borderSkipped: 'start',
    }
  end
end
