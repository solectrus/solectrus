class ChartData::InverterPower < ChartData::Base
  def initialize(timeframe:, sensor: nil, variant: nil)
    super(timeframe:)
    @sensor = sensor || :inverter_power
    @variant = variant || 'total'
  end

  attr_reader :sensor, :variant

  private

  def data
    @data ||=
      if sensor == :inverter_power && stackable?
        data_stacked
      elsif sensor == :inverter_power && timeframe.day?
        data_with_forecast
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
    sensor_names = SensorConfig.x.existing_custom_inverter_sensor_names

    datasets = sensor_names.map { |name| dataset(name) }
    datasets << dataset(:inverter_power_difference)

    { labels:, datasets: }
  end

  def labels
    chart.values.first&.map { |x| x.first.to_i * 1000 }
  end

  def dataset(sensor_name)
    {
      id: sensor_name,
      label: SensorConfig.x.display_name(sensor_name),
      data: values_for(sensor_name),
    }.merge(style(sensor_name))
  end

  def values_for(sensor_name)
    case sensor_name
    when :inverter_power
      if SensorConfig.x.inverter_total_present?
        simple_sensor_values(sensor_name)
      else
        calculated_inverter_total_values
      end
    when :inverter_power_difference
      inverter_power_difference_values
    else
      simple_sensor_values(sensor_name)
    end
  end

  def chart
    # Interpolation required because the forecast data has a lower resolution

    @chart ||=
      PowerChart.new(sensors:).call(timeframe, interpolate: variant == 'total')
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

  BACKGROUND_COLORS = {
    inverter_power_forecast: '#cbd5e1', # bg-slate-300
    inverter_power: '#16a34a', # bg-green-600
    inverter_power_1: '#11622f', # +10%
    inverter_power_2: '#147638', # +10%
    inverter_power_3: '#178941', # +10%
    inverter_power_4: '#1b9d4b', # +10%
    inverter_power_5: '#1eb154', # +10%
    inverter_power_difference: '#5B807B', # bg-green-900/50
  }.freeze

  private_constant :BACKGROUND_COLORS

  def style(sensor_name)
    addon =
      if sensor_name == :inverter_power_forecast
        nil
      elsif stackable?
        { stack: 'InverterPower' }
      end

    super().merge({ **addon, backgroundColor: BACKGROUND_COLORS[sensor_name] })
  end

  def stackable?
    sensor == :inverter_power && SensorConfig.x.multi_inverter? &&
      variant == 'split'
  end

  def inverter_power_difference_values
    total_values = simple_sensor_values(:inverter_power)
    inverter_values = individual_inverter_values

    # If no individual inverter values exist, show the entire total as "difference"
    return total_values if inverter_values.empty?

    calculate_differences(total_values, inverter_values)
  end

  def simple_sensor_values(sensor_name)
    chart[sensor_name]&.map { |_, v| v&.negative? ? 0 : v } || []
  end

  def individual_inverter_values
    SensorConfig.x.existing_custom_inverter_sensor_names.filter_map do |name|
      simple_sensor_values(name)
    end
  end

  def calculated_inverter_total_values
    inverter_values = individual_inverter_values
    return [] if inverter_values.empty?

    max_length = inverter_values.map(&:length).max
    Array.new(max_length) do |i|
      inverter_values.filter_map { |arr| arr[i] }.sum
    end
  end

  def calculate_differences(total_values, inverter_values)
    process_inverter_data(
      total_values,
      inverter_values,
    ) do |total_value, parts_sum|
      if total_value
        difference = total_value - parts_sum
        difference if significant_difference?(difference, total_value)
      end
    end
  end

  def process_inverter_data(total_values, inverter_values)
    max_length = [
      total_values.length,
      inverter_values.first&.length,
    ].compact.max

    Array.new(max_length) do |i|
      total_value = total_values[i]
      parts_sum = inverter_values.filter_map { |arr| arr[i] }.sum
      yield(total_value, parts_sum)
    end
  end

  # Minimum threshold (percent and absolute) for showing inverter power differences
  DIFFERENCE_THRESHOLD_PERCENT = 1.0
  DIFFERENCE_THRESHOLD = 2
  private_constant :DIFFERENCE_THRESHOLD_PERCENT
  private_constant :DIFFERENCE_THRESHOLD

  def significant_difference?(difference, total_value)
    return false unless difference.positive? && total_value.positive?

    ratio = difference.fdiv(total_value) * 100
    ratio > DIFFERENCE_THRESHOLD_PERCENT && difference > DIFFERENCE_THRESHOLD
  end
end
