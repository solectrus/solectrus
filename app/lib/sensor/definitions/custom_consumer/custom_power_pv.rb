class Sensor::Definitions::CustomPowerPv < Sensor::Definitions::Base
  # Use the same MAX as CustomPower since they're related
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  def name
    :"custom_power_#{formatted_number}_pv"
  end

  value unit: :watt, range: (0..), category: :power_splitter

  color background: 'bg-sensor-pv',
        text: 'text-white dark:text-slate-400'

  depends_on do
    [
      :"custom_power_#{formatted_number}",
      :"custom_power_#{formatted_number}_grid",
    ]
  end

  calculate do |**kwargs|
    custom_power_key = :"custom_power_#{formatted_number}"
    custom_power_grid_key = :"custom_power_#{formatted_number}_grid"

    custom_power = kwargs[custom_power_key]
    return unless custom_power

    custom_power_grid = kwargs[custom_power_grid_key]
    return custom_power unless custom_power_grid

    [custom_power - custom_power_grid, 0].max
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  requires_permission :power_splitter

  private

  def formatted_number
    format('%02d', @number)
  end
end
