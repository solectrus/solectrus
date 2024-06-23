class ChartData::MixedChart < ChartData::Base
  private

  def data
    { labels: common_labels_for_mixed_chart, datasets: mixed_chart_datasets }
  end

  def common_labels_for_mixed_chart
    (
      inverter_power || house_power_total_consumed || house_power_self_consumed
    )&.map { |x| x.first.to_i * 1000 }
  end

  def mixed_chart_datasets
    [
      build_dataset(:house_power_self_consumed),
      build_dataset(:inverter_power),
      build_dataset(:house_power_total_consumed),
    ]
  end

  def build_dataset(sensor_name)
    {
      label: I18n.t("sensors.#{sensor_name}"),
      data: __send__(sensor_name)&.map(&:second),
    }.merge(style(sensor_name))
  end

  def inverter_power
    @inverter_power ||=
      PowerChart.new(sensors: [:inverter_power]).call(
        timeframe,
        interpolate: true,
      )[
        :inverter_power
      ]
  end

  def house_power_total_consumed
    @house_power_total_consumed ||=
      house_power_aggregator(
        PowerChart.new(sensors: consumer_sensors).call(timeframe),
        'total',
      )
  end

  def consumer_sensors
    # All consumers - Except the ones that are already included in house_power
    %i[
      house_power
      heatpump_power
      wallbox_power
      battery_charging_power
    ].select do |sensor|
      SensorConfig.x.exists?(sensor) &&
        SensorConfig.x.exclude_from_house_power.exclude?(sensor)
    end
  end

  def house_power_self_consumed
    @house_power_self_consumed ||=
      house_power_aggregator(
        PowerChart.new(sensors: %i[grid_export_power inverter_power]).call(
          timeframe,
        ),
        'self',
      )
  end

  def house_power_aggregator(power_chart, house_power_variant) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    aggregated_data = {}

    power_chart.each_value do |sensor_data|
      sensor_data.each do |timestamp, power_value|
        next unless power_value

        if aggregated_data[timestamp]
          case house_power_variant
          when 'total'
            aggregated_data[timestamp] += power_value
          when 'self'
            aggregated_data[timestamp] -= power_value
          end
        else
          aggregated_data[timestamp] = power_value
        end
      end
    end

    aggregated_data.map do |timestamp, computed_value|
      [timestamp, computed_value&.abs]
    end
  end

  COLORS = {
    house_power_self_consumed: '#0369a1', # bg-sky-700
    inverter_power: '#16a34a', # bg-green-600
    house_power_total_consumed: '#dc2626', # bg-red-600
  }.freeze
  private_constant :COLORS

  FILL = {
    house_power_self_consumed: 'origin',
    inverter_power: '-1',
    house_power_total_consumed: 'stack',
  }.freeze
  private_constant :FILL

  def style(sensor_name)
    super().merge(backgroundColor: COLORS[sensor_name], fill: FILL[sensor_name])
  end
end
