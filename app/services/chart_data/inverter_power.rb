class ChartData::InverterPower < ChartData::Base
  def initialize(timeframe:, sensor: :inverter_power)
    super(timeframe:)
    @sensor = sensor
  end

  attr_reader :sensor

  private

  def data
    @data ||=
      if timeframe.day? && sensor == :inverter_power
        data_with_forecast
      elsif stacked?
        data_stacked
      else
        data_simple
      end
  end

  def data_simple
    { labels:, datasets: [dataset(sensor)] }
  end

  def data_with_forecast
    { labels:, datasets: [dataset(sensor), dataset(:inverter_power_forecast)] }
  end

  def data_stacked
    sensor_names = SensorConfig.x.inverter_sensor_names - [:inverter_power]

    datasets = sensor_names.map { |name| dataset(name) }

    # Fallback, if all datasets are empty
    # This can happen when the inverter_power_1/2/3/4/5 are not given
    datasets = [dataset(sensor)] if datasets.all? { |d| d[:data].blank? }

    { labels:, datasets: }
  end

  def labels
    chart.values.first&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(sensor_name)
    {
      label: SensorConfig.x.display_name(sensor_name),
      data: values_for(sensor_name),
    }.merge(style(sensor_name))
  end

  def values_for(sensor_name) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    if sensor_name == :inverter_power && !SensorConfig.x.inverter_total_present?
      inverter_values =
        SensorConfig.x.inverter_sensor_names.map { |name| values_for(name) }

      length = inverter_values.first.length
      Array.new(length) do |i|
        inverter_values.sum do |arr|
          value = arr[i]
          (value&.negative? ? 0 : value) || 0
        end
      end
    else
      chart[sensor_name]&.map { |_, v| v&.negative? ? 0 : v } || []
    end
  end

  def chart
    # Interpolation required because the forecast data has a lower resolution

    @chart ||= PowerChart.new(sensors:).call(timeframe, interpolate: true)
  end

  def sensors
    base =
      if sensor == :inverter_power
        SensorConfig.x.inverter_sensor_names
      else
        [sensor]
      end

    timeframe.day? ? base + [:inverter_power_forecast] : base
  end

  INVERTER_COLOR = '#16a34a'.freeze # bg-green-600
  private_constant :INVERTER_COLOR

  BACKGROUND_COLORS = {
    inverter_power: INVERTER_COLOR,
    inverter_power_forecast: '#cbd5e1', # bg-slate-300
  }.merge(
    SensorConfig::CUSTOM_INVERTER_SENSORS.index_with { INVERTER_COLOR },
  ).freeze

  private_constant :BACKGROUND_COLORS

  def style(sensor_name)
    stack =
      if sensor_name == :inverter_power_forecast
        nil
      elsif stacked?
        'InverterPower'
      end

    super().merge(
      { backgroundColor: BACKGROUND_COLORS[sensor_name], stack: }.compact,
    )
  end

  def stacked?
    sensor == :inverter_power && SensorConfig.x.multi_inverter? &&
      !timeframe.short?
  end
end
