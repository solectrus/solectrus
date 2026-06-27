class Sensor::Definitions::CustomCosts < Sensor::Definitions::Base
  MAX = Sensor::Definitions::CustomPower::MAX
  public_constant :MAX

  def initialize(number)
    @number = number
    super()
  end

  attr_reader :number

  def name
    :"custom_#{formatted_number}_costs"
  end

  value unit: :money, category: :economic

  depends_on do
    [
      :"custom_#{formatted_number}_costs_grid",
      :"custom_#{formatted_number}_costs_pv",
    ]
  end

  # Deps derive purely from the consumer number; expose them statically so
  # Sensor::Config#exists? prunes this sensor when its consumer is unconfigured
  # (block-form depends_on alone would leak a phantom for every slot).
  def static_dependencies = dependencies

  calculate do |**kwargs|
    custom_costs_grid = kwargs[:"custom_#{formatted_number}_costs_grid"]
    custom_costs_pv = kwargs[:"custom_#{formatted_number}_costs_pv"]

    custom_costs_grid + custom_costs_pv if custom_costs_grid && custom_costs_pv
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  private

  def formatted_number
    format('%02d', number)
  end
end
