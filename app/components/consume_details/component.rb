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
      )
  end
end
