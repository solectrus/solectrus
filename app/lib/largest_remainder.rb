# Whole numbers for a list of shares, for example percentages in a tooltip.
# Largest remainder method: the rounded values add up to the rounded total
# (usually 100), which rounding each value on its own does not guarantee
# (72 + 14 + 15).
#
#   LargestRemainder.round([72.4, 13.6, 14.0]) # => [72, 14, 14]
module LargestRemainder
  def self.round(values)
    rounded = values.map(&:floor)
    missing = values.sum.round - rounded.sum

    values
      .each_index
      .max_by(missing) { |i| values[i] - rounded[i] }
      .each { |i| rounded[i] += 1 }

    rounded
  end
end
