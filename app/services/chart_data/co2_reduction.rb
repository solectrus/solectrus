class ChartData::Co2Reduction < ChartData::InverterPower
  def initialize(timeframe:)
    super(timeframe:, sensor: :co2_reduction)
  end

  private

  def data
    result = dataset(:inverter_power)
    result[:data].map! do |value|
      value&.positive? ? (value * co2_reduction_factor).round : nil
    end

    { labels:, datasets: [result] }
  end

  def co2_reduction_factor
    @co2_reduction_factor ||=
      Rails.application.config.x.co2_emission_factor.fdiv(
        if timeframe.short?
          # g per hour
          24.0
        else
          # kg
          1000.0
        end,
      )
  end

  def chart
    @chart ||=
      PowerChart.new(sensors: SensorConfig.x.inverter_sensor_names).call(
        timeframe,
      )
  end

  def style(_sensor_name)
    super.merge(
      backgroundColor: '#0369a1', # bg-sky-700
    )
  end
end
