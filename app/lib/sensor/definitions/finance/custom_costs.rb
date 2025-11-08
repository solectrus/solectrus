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
    if Setting.opportunity_costs
      [
        :"custom_costs_#{formatted_number}_grid",
        :"custom_costs_#{formatted_number}_pv",
      ]
    else
      [:"custom_costs_#{formatted_number}_grid"]
    end
  end

  calculate do |**kwargs|
    custom_costs_grid = kwargs[:"custom_costs_#{formatted_number}_grid"]
    custom_costs_pv = kwargs[:"custom_costs_#{formatted_number}_pv"]

    if Setting.opportunity_costs
      if custom_costs_grid && custom_costs_pv
        custom_costs_grid + custom_costs_pv
      end
    else
      custom_costs_grid
    end
  end

  aggregations stored: false, computed: [:sum], meta: [:sum]

  private

  def formatted_number
    format('%02d', number)
  end
end
