class HouseBreakdown::TooltipComponent < ViewComponent::Base
  def initialize(sensor:, data:, timeframe:)
    super()
    @sensor = sensor
    @data = data
    @timeframe = timeframe
  end

  attr_reader :sensor, :data, :timeframe

  def call
    tag.div class: 'flex flex-col items-center justify-center min-w-32 p-2 gap-2' do
      safe_join(
        [
          sensor.display_name,
          sensor_value,
          costs_component,
        ].compact,
      )
    end
  end

  private

  def sensor_value
    if timeframe.now?
      render SensorValue::Component.new(data, sensor.name, precision: 3)
    else
      render SensorValue::Component.new(data, sensor.name, context: :total, precision: 3, class: 'text-xl')
    end
  end

  def costs_component
    return if timeframe.now?
    return unless costs

    render SplittedCosts::Component.new(power_grid_ratio:, costs:, grid_costs:, pv_costs:)
  end

  def costs
    return @costs if defined?(@costs)

    @costs =
      if ApplicationPolicy.power_splitter?
        costs_field = "#{sensor.name}_costs".sub('_power', '')
        data.public_send(costs_field) if data.respond_to?(costs_field)
      end
  end

  def power_grid_ratio
    field = :"#{sensor.name}_grid_ratio"
    data.respond_to?(field) ? data.public_send(field) : nil
  end

  def grid_costs
    sensor_costs_field(:costs_grid_sensor_name)
  end

  def pv_costs
    sensor_costs_field(:costs_pv_sensor_name)
  end

  def sensor_costs_field(method)
    field = sensor.public_send(method)
    field && data.respond_to?(field) ? data.public_send(field) : nil
  end
end
