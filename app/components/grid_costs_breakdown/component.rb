class GridCostsBreakdown::Component < ViewComponent::Base
  def initialize(data:)
    super()
    @data = data
  end

  attr_reader :data

  # The base fee keeps its value, the energy costs take the rest, so the rows
  # add up to the grid costs as shown.
  def costs
    @costs ||=
      RoundedSum.new([data.grid_base_fee, raw_energy_costs], unit: :money)
  end

  # Only worth splitting where there is a fee to split off. An install without
  # a grid meter has no energy costs, and no breakdown either.
  def breakdown?
    data.try(:grid_base_fee).to_f.positive? && raw_energy_costs.present?
  end

  private

  def raw_energy_costs
    @raw_energy_costs ||= data.try(:grid_energy_costs)
  end
end
