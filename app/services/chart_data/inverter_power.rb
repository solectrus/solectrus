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

    total = dataset(:inverter_power)
    parts = sensor_names.map { |name| dataset(name) }

    # Fallback: Check each period if the total is the sum of the parts
    total[:data].each_index do |i|
      total_value = total[:data][i]
      part_values = parts.map { |ds| ds[:data][i] }

      if valid_parts?(total_value, part_values)
        # Parts are fine => Hide the total
        total[:data][i] = nil
      else
        # Parts are missing or incomplete => hide them
        parts.each { |ds| ds[:data][i] = nil }
      end
    end

    { labels:, datasets: (parts.presence + [total]) || [total] }
  end

  def valid_parts?(total, parts)
    return true unless total
    return false if parts.any?(&:nil?) || total.zero?

    ratio = (parts.sum.fdiv(total) * 100).round
    ratio >= 99 # 1% tolerance
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
        inverter_values
          .filter_map do |arr|
            value = arr[i]
            value&.negative? ? 0 : value
          end
          .presence
          &.sum
      end
    else
      chart[sensor_name]&.map { |_, v| v&.negative? ? 0 : v } || []
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

  # Example:
  # 'bg-[#373737] text-slate-100' => '#373737'
  private_class_method def self.hex_from_tw_class(class_name)
    # Extract the hex color code from the class name
    match = class_name.match(/bg-\[(#[0-9a-fA-F]{8})\]/)
    return unless match

    # Return the hex color code
    match[1]
  end

  BACKGROUND_COLORS = {
    inverter_power_forecast: '#cbd5e1', # bg-slate-300
    inverter_power: '#16a34a', # bg-green-600
    #
    inverter_power_1:
      hex_from_tw_class(Segment::Component::COLOR_SET_INVERTER.first),
    inverter_power_2:
      hex_from_tw_class(Segment::Component::COLOR_SET_INVERTER.second),
    inverter_power_3:
      hex_from_tw_class(Segment::Component::COLOR_SET_INVERTER.third),
    inverter_power_4:
      hex_from_tw_class(Segment::Component::COLOR_SET_INVERTER.fourth),
    inverter_power_5:
      hex_from_tw_class(Segment::Component::COLOR_SET_INVERTER.fifth),
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
      !timeframe.now? && variant == 'split'
  end
end
