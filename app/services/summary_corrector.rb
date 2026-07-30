# This class adjusts the PowerSplitter values to match the grid energy that was
# actually available. This mainly corrects rounding errors.
#
# In rare cases (e.g. in the event of a meter failure), the PowerSplitter
# may calculate incorrect values.
#
# This class does two things to fix this:
#
#  1) Ensures that the grid power of each consumer is never higher than the
#     total consumption of that consumer.
#  2) Ensures that the sum of all grid powers is equal to #grid_total.
#
class SummaryCorrector
  # Sources of grid energy - they are not consumers and take no part in the
  # distribution, they define the target the consumers are scaled to.
  GRID_SOURCE_KEYS = %i[
    grid_import_power
    battery_discharging_power_grid
  ].freeze
  private_constant :GRID_SOURCE_KEYS

  # The sensors a caller has to hand in alongside the consumers, so #grid_total
  # knows the target to scale them to.
  def self.grid_source_sensors
    GRID_SOURCE_KEYS.map { Sensor::Registry[it] }
  end

  def initialize(attributes)
    # Grid energy the consumers can have received: what came from the grid
    # directly, plus what the battery handed back out of grid energy stored
    # earlier. An older Power Splitter does not report the latter, and then the
    # consumers' grid shares add up to the plain grid import, as they always did.
    grid_import_power = attributes[:grid_import_power]
    @grid_total =
      grid_import_power &&
        (grid_import_power + (attributes[:battery_discharging_power_grid] || 0))
    @power_pairs = extract_power_pairs(attributes.except(*GRID_SOURCE_KEYS))
  end

  attr_reader :power_pairs

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

  attr_reader :grid_total

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
        .transform_values { (it[:consumption] || 0).clamp(0, nil) }
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

    factor = grid_total&.fdiv(total_consumption) || 1

    consumptions.each_key do |key|
      power_pairs[key][:grid] = (consumptions[key] * factor).round(1)
    end
  end

  def scale_and_adjust(grid_powers, consumptions)
    factor = grid_total&.fdiv(grid_powers.values.sum) || 1

    adjusted =
      grid_powers.to_h do |key, value|
        # Scale, but limit to consumption
        [key, (value * factor).clamp(0, consumptions[key])]
      end

    # Calculate and distribute remaining power
    if grid_total
      remaining = grid_total - adjusted.values.sum
      distribute_remaining(adjusted, remaining, consumptions)
    end

    adjusted.each { |key, value| power_pairs[key][:grid] = value.round(1) }
  end

  # Hand the remaining power to the consumers that still have room for it.
  #
  # An even split alone is not enough: consumers reach their consumption ceiling
  # at different points, and whatever a full one could not take would simply be
  # dropped - a consumer with a single watt of headroom would swallow a whole
  # share. So repeat over the ones that still have room until the remainder is
  # gone or nobody can take any more.
  # Each round either exhausts the remainder or fills at least one consumer up to
  # its ceiling, so there can never be more rounds than there are consumers. The
  # bound also keeps a float remainder that never quite closes from spinning.
  def distribute_remaining(adjusted, remaining, consumptions)
    adjusted.size.times do
      break if remaining.abs < 0.5

      adjustable_keys =
        adjusted.keys.select { |key| adjusted[key] < consumptions[key] }
      break if adjustable_keys.empty?

      per_item = remaining.fdiv(adjustable_keys.size)

      adjustable_keys.each do |key|
        increase = [per_item, consumptions[key] - adjusted[key]].min
        adjusted[key] += increase
        remaining -= increase
      end
    end
  end
end
