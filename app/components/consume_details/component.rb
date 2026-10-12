class ConsumeDetails::Component < ViewComponent::Base
  def initialize(data:)
    super()
    @data = data
  end

  attr_accessor :data

  # The tooltip belongs to the key figure of the grid costs, so they come first
  # and keep their value. The opportunity costs take the rest of the total.
  def costs
    @costs ||=
      RoundedSum.new(
        [data.grid_costs, data.opportunity_costs],
        unit: :money,
        **shared_precision,
      )
  end

  # The grid costs split into base fee and energy costs. The base fee keeps its
  # value, the energy costs take the rest of the grid costs.
  def import_costs
    @import_costs ||=
      RoundedSum.new(
        [data.grid_base_fee, raw_energy_costs],
        unit: :money,
        **shared_precision,
      )
  end

  # Only worth splitting where there is a fee to split off.
  def base_fee?
    data.try(:grid_base_fee).to_f.positive? && raw_energy_costs.present?
  end

  private

  # Both sums print the grid costs, so with the breakdown they share one
  # precision: the finest that any row needs. Without it, the single sum finds
  # its own.
  def shared_precision
    return {} unless base_fee?

    @shared_precision ||= {
      precision:
        RoundedSum.finest_formatter(
          [
            raw_energy_costs,
            data.grid_base_fee,
            data.grid_costs,
            data.opportunity_costs,
            data.total_costs,
          ],
          unit: :money,
        ).precision,
    }
  end

  # Absent on an install without a grid meter, and the breakdown with it.
  def raw_energy_costs
    @raw_energy_costs ||= data.try(:grid_energy_costs)
  end
end
