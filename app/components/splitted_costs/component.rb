class SplittedCosts::Component < ViewComponent::Base
  # costs may be nil: the battery has a grid share worth showing, but no costs
  # of its own -- what it stores is billed to the consumers that take it back
  # out again, through their own grid share. Such a segment passes a note
  # saying so, otherwise the missing amount reads as "free".
  #
  # base_fee is the part of grid_costs that is the base fee of the tariff. Only
  # the house carries one, and the breakdown then reads as a calculation:
  # base fee + energy costs = grid costs, + opportunity costs = total.
  def initialize( # rubocop:disable Metrics/ParameterLists
    power_grid_ratio:,
    costs: nil,
    grid_costs: nil,
    pv_costs: nil,
    base_fee: nil,
    note: nil,
    show_power_breakdown: true
  )
    super()
    @costs = costs
    @grid_costs = grid_costs
    @base_fee = base_fee
    @pv_costs = pv_costs
    @power_grid_ratio = power_grid_ratio
    @note = note
    @show_power_breakdown = show_power_breakdown
  end

  attr_reader :power_grid_ratio, :note

  # With a breakdown, the total is the one the key figures show, and the parts
  # add up to it as shown: 2,323 and 3,504 show as 2,32 + 3,51 = 5,83, not
  # 2,32 + 3,50.
  def costs
    breakdown? ? rounded.sum : @costs
  end

  # With a base fee, the subtotal of the two rows as shown
  def grid_costs
    return unless @grid_costs
    return rounded.parts.first unless base_fee?

    (base_fee + energy_costs).round(precision)
  end

  def base_fee
    rounded.parts.first if base_fee?
  end

  def energy_costs
    rounded.parts.second if base_fee?
  end

  def pv_costs
    rounded.parts.last if @pv_costs
  end

  def base_fee?
    @grid_costs && @base_fee&.positive?
  end

  # The sign in front of a row of the calculation. The first row has none, but
  # keeps the space, so all labels start in one column.
  def operator(sign)
    return unless base_fee?

    tag.span(sign, class: 'inline-block w-4')
  end

  # All amounts of the breakdown share one precision, so 4,83 + 10,20 = 15,03
  # instead of 4,83 + 10 = 15
  def precision
    rounded.precision if breakdown?
  end

  def power_pv_ratio
    return unless power_grid_ratio

    100 - power_grid_ratio
  end

  def breakdown?
    @grid_costs || @pv_costs
  end

  def costs?
    !costs.nil?
  end

  def show_power_breakdown?
    @show_power_breakdown
  end

  private

  def rounded
    @rounded ||= RoundedSum.new(raw_parts, unit: :money)
  end

  # With a base fee, the grid costs split into the fee and the energy costs, in
  # the order of GridCostsBreakdown::Component, so all three rows add up to the
  # total as shown.
  def raw_parts
    if base_fee?
      [@base_fee, @grid_costs - @base_fee, @pv_costs.to_f]
    else
      [@grid_costs.to_f, @pv_costs.to_f]
    end
  end
end
