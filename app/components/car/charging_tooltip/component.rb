# The tooltip of the ring on the charging card of the car page. It gives the
# share and the cost of each source of the charged energy: PV and grid of the
# home wallbox, or the wallbox alone without the power splitter, and the
# offsite sessions. The card shows their energy below the ring. The costs
# add up to the charging cost. A guest session belongs to no car, so its cost
# is a loss of its own and not a part of the total.
class Car::ChargingTooltip::Component < ViewComponent::Base
  # The parts by source in the order of the sources (see
  # Car::Report#sources) and their sum, rounded to add up (see RoundedSum),
  # with the format options of the rounding
  Costs = Data.define(:parts, :sum, :options) do
    # The costs of { source => cost }. The largest part takes the rest of the
    # rounding, so a part of zero never shows a cent.
    def self.of(parts)
      by_size = parts.keys.sort_by { parts[it].abs }
      rounded = RoundedSum.new(parts.values_at(*by_size), unit: :money)

      new(parts: by_size.zip(rounded.parts).to_h.slice(*parts.keys), sum: rounded.sum, options: rounded.options)
    end
  end
  public_constant :Costs

  # A source with its key and its whole share in percent
  Source = Data.define(:key, :whole_percent)
  public_constant :Source

  # `sources` are the sources with energy. `costs` is nil when no session has
  # a cost, and `complete` tells whether each session has one.
  def initialize(sources:, costs:, guest_cost:, complete:)
    super()
    @sources = sources
    @costs = costs
    @guest_cost = guest_cost
    @complete = complete
  end

  attr_reader :sources, :costs, :guest_cost

  def complete? = @complete

  def color_class(source) = Car::ChargingSource[source.key].color_class

  def label(source) = t(Car::ChargingSource[source.key].label_key)

  def cost_value(cost, **)
    SensorValue::Component.new(cost, :total_costs, **costs.options, **)
  end
end
