class HouseBreakdown::Tooltip::Component < ViewComponent::Base
  def initialize(sensor:, data:, timeframe:)
    super()
    @sensor = sensor
    @data = data
    @timeframe = timeframe
  end

  attr_reader :sensor, :data, :timeframe

  def call
    tag.div class: 'tooltip-layout' do
      safe_join(
        [
          render(TooltipHeader::Component.new(title: sensor.display_name, sensor_name: sensor.name, value: data, total: !timeframe.now?)),
          costs_component,
        ].compact,
      )
    end
  end

  private

  def costs_component
    return if timeframe.now?
    return unless costs

    render SplittedCosts::Component.new(power_grid_ratio:, costs:, grid_costs:, pv_costs:, base_fee:)
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

  def base_fee
    data.try(:grid_base_fee) if sensor.costs_carry_base_fee?
  end

  def sensor_costs_field(method)
    field = sensor.public_send(method)
    field && data.respond_to?(field) ? data.public_send(field) : nil
  end
end
