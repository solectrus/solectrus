# This class adjusts the PowerSplitter values to match the grid_import_power.
# This mainly corrects rounding errors.
#
# In rare cases (e.g. in the event of a meter failure), the PowerSplitter
# may calculate incorrect values.
#
# This class does two things to fix this:
#
#  1) Ensures that the grid power of each consumer is never higher than the
#     total consumption of that consumer.
#  2) Ensures that the sum of all grid powers is equal to the grid_import_power.
#
class SummaryCorrector
  def initialize(attributes)
    @grid_import_power = attributes[:grid_import_power]
    @power_pairs = extract_power_pairs(attributes.except(:grid_import_power))
  end

  attr_reader :grid_import_power, :power_pairs

  # Return the corrected grid attributes
  def adjusted
    return @adjusted if defined?(@adjusted)

    fix_grid_values

    @adjusted =
      power_pairs
        .transform_values { it[:grid] }
        .compact
        .transform_keys { :"#{it}_grid" }
  end

  private

  def extract_power_pairs(attributes)
    pairs = {}

    attributes.each do |key, value|
      base_key = key.to_s

      if base_key.delete_suffix!('_grid')
        (pairs[base_key.to_sym] ||= {})[:grid] = value
      else
        (pairs[base_key.to_sym] ||= {})[:consumption] = value
      end
    end

    pairs
  end

  def fix_grid_values
    grid_powers = power_pairs.transform_values { it[:grid] }.compact
    return if grid_powers.empty?

    grid_power_total = grid_powers.values.sum

    consumptions =
      power_pairs
        .transform_values { it[:consumption] || 0 }
        .slice(*grid_powers.keys)

    if grid_power_total.zero?
      distribute_evenly(consumptions)
    else
      scale_and_adjust(grid_powers, consumptions)
    end
  end

  def distribute_evenly(consumptions)
    total_consumption = consumptions.values.sum
    return if total_consumption.zero?

    factor = grid_import_power&.fdiv(total_consumption) || 1

    consumptions.each_key do |key|
      power_pairs[key][:grid] = (consumptions[key] * factor).round(1)
    end
  end

  def scale_and_adjust(grid_powers, consumptions)
    factor = grid_import_power&.fdiv(grid_powers.values.sum) || 1

    adjusted =
      grid_powers.to_h do |key, value|
        # Scale, but limit to consumption
        [key, (value * factor).clamp(0, consumptions[key])]
      end

    # Calculate and distribute remaining power
    if grid_import_power
      remaining = grid_import_power - adjusted.values.sum
      distribute_remaining(adjusted, remaining, consumptions)
    end

    adjusted.each { |key, value| power_pairs[key][:grid] = value.round(1) }
  end

  def distribute_remaining(adjusted, remaining, consumptions)
    return if remaining.abs < 0.5

    adjustable_keys =
      adjusted.keys.select { |key| adjusted[key] < consumptions[key] }

    return if adjustable_keys.empty?

    per_item = remaining.fdiv(adjustable_keys.size)

    adjustable_keys.each do |key|
      increase = [per_item, consumptions[key] - adjusted[key]].min
      adjusted[key] += increase
      remaining -= increase
    end
  end
end
