# The parts of a sum and the sum itself, rounded the way a tooltip shows them:
# all to the same digits, so the parts add up to the sum as shown (2,32 + 3,51
# = 5,83, not 2,32 + 3,50). The sum and all parts but one round as usual. That
# part, the last one unless `rest:` gives its index, is what the others leave
# of the sum.
#
# The digits are the finest that any of the values needs, so a small amount
# keeps its cents: in whole euros, 3,47 - 0,89 = 2,58 could only show as
# 3 - 0 = 3.
#
# The options are those of Sensor::ValueFormatter. The values must be printed
# with #options, or their digits differ again.
#
#   costs = RoundedSum.new([2.323, 3.504], unit: :money)
#   costs.parts     # => [2.32, 3.51]
#   costs.sum       # => 5.83
#   costs.options   # => { precision: 2 }, or {} when a part is missing
#
#   Sensor::Value::Component.new(costs.sum, :total_costs, **costs.options)
#
#   RoundedSum.new([2.323, 3.504], rest: 0, unit: :money).parts # => [2.33, 3.5]
#
# A part that goes the other way comes negated. A sum that its sensor clamps
# takes the sensor's range, and its parts then round on their own:
#
#   RoundedSum.new(
#     [inverter_power, -grid_export_power],
#     range: Sensor::Registry[:self_consumption].value_range,
#   )
class RoundedSum
  # The formatter of the value with the most decimals. The values share one
  # unit, so its digits and divisor fit them all.
  def self.finest_formatter(values, **format)
    values
      .compact
      .map { Sensor::ValueFormatter.new(it, **format) }
      .max_by(&:precision)
  end

  def initialize(parts, range: nil, rest: nil, **format)
    @raw_parts = parts
    @range = range
    @rest = rest
    @format = format
  end

  def precision
    formatter.precision if complete?
  end

  # What Sensor::Value::Component needs to print every value of the sum alike
  def options
    @options ||= @format.except(:unit).merge({ precision: }.compact)
  end

  def parts
    return @raw_parts unless complete?

    @parts ||=
      # A clamped sum is not the sum of the parts, so no part may take the rest
      if clamped?
        @raw_parts.map { round(it) }
      else
        parts_taking_the_rest
      end
  end

  def sum
    return unless complete?

    @sum ||= round(raw_sum)
  end

  private

  # Without all parts there is nothing to add up, so they stay as they are
  def complete?
    @raw_parts.all?
  end

  def clamped?
    @range && !@range.cover?(@raw_parts.sum)
  end

  def raw_sum
    @raw_sum ||= @range ? @raw_parts.sum.clamp(@range) : @raw_parts.sum
  end

  def parts_taking_the_rest
    parts = @raw_parts.map { round(it) }
    return parts if parts.empty?

    rest = @rest || (parts.size - 1)
    parts[rest] = round(sum - (parts.sum - parts[rest]))
    parts
  end

  # Rounds as printed: 12 345 Wh to 12,3 kWh, which is 12 300 Wh
  def round(value)
    divisor = formatter.divisor
    value.fdiv(divisor).round(formatter.precision) * divisor
  end

  def formatter
    @formatter ||= self.class.finest_formatter([raw_sum, *@raw_parts], **@format)
  end
end
