class Sensor::Chart::TotalConsumption < Sensor::Chart::Base
  include Sensor::Chart::Concerns::GapBridging

  # Show the total consumption broken down into its parts. Order is the stacking
  # order (bottom to top): house, then heat pump, then wallbox. house_power is
  # already net of heat pump / wallbox (they are excluded from it), so the three
  # stacked segments add up to the total without double counting.
  COMPONENT_SENSOR_NAMES = %i[house_power heatpump_power wallbox_power].freeze
  public_constant :COMPONENT_SENSOR_NAMES

  def label
    Sensor::Registry[:total_consumption].display_name
  end

  def options
    super.deep_merge(
      plugins: {
        legend: legend_options,
      },
      scales: {
        x: {
          stacked: true,
        },
        y: {
          stacked: true,
        },
      },
    )
  end

  private

  def chart_sensor_names
    @chart_sensor_names ||=
      COMPONENT_SENSOR_NAMES.select { |name| Sensor::Config.exists?(name) }
  end

  def build_chart_data_items
    items = super
    # A stacked line fill (fill: '-1') needs a numeric value at every index.
    pad_nil_values!(items) if type == 'line'
    items
  end

  # Heat pump and wallbox are excluded from house_power, so their nil buckets
  # mean "no power" (0) and must stay 0 -- bridging them would carry a value
  # that house_power has not been reduced by. house_power itself bridges short
  # outages so a brief dropout doesn't read as a drop to zero.
  def pad_nil_values!(items)
    items.each do |item|
      if item[:sensor_name] == :house_power
        bridge_short_outages!(item[:data])
      else
        item[:data].map! { |value| value || 0 }
      end
    end
  end

  def datasets(chart_data_items)
    chart_data_items.map do |chart_data|
      sensor = Sensor::Registry[chart_data[:sensor_name]]
      {
        id: sensor.name.to_s,
        label: sensor.display_name,
        data: chart_data[:data],
      }.merge(style_for_dataset(sensor))
    end
  end

  def style_for_dataset(sensor)
    position = chart_sensor_names.index(sensor.name) || 0
    fill =
      if type == 'line'
        position.zero? ? 'origin' : '-1'
      else
        true
      end

    style_for_sensor(sensor).merge(
      fill:,
      stack: 'TotalConsumption',
      noGradient: true,
      colorClass: sensor.color_background,
    )
  end
end
