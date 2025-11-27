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

  value unit: :euro, category: :economic

  depends_on do
    [
      :"custom_costs_#{formatted_number}_grid",
      :"custom_costs_#{formatted_number}_pv",
    ]
  end

  calculate do |**kwargs|
    custom_costs_grid = kwargs[:"custom_costs_#{formatted_number}_grid"]
    custom_costs_pv = kwargs[:"custom_costs_#{formatted_number}_pv"]

    custom_costs_grid + custom_costs_pv if custom_costs_grid && custom_costs_pv
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  private

  def formatted_number
    format('%02d', number)
  end
end
