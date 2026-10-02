# The charging cost of the car page by source, rounded as shown, so the parts
# add up to the total (see RoundedSum). The card and its tooltip show the
# same parts, so both round them here.
module CarRoundedCosts
  Costs = Data.define(:parts, :sum, :options)
  private_constant :Costs

  private

  # { source => cost } in, Costs out. The largest part takes the rest of the
  # rounding, so a part of zero never shows a cent.
  def rounded_costs(costs)
    sources = costs.keys.sort_by { costs[it].abs }
    rounded = RoundedSum.new(costs.values_at(*sources), unit: :money)

    Costs.new(parts: sources.zip(rounded.parts).to_h, sum: rounded.sum, options: rounded.options)
  end
end
