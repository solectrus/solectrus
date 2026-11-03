module McpServer
  module Tools
    class CarCosts < Base
      # The comparison of the cars with a combustion car for the same distance
      # (see Car::Comparison), as the part of the response of get_car_costs
      # that the comparison page shows.
      #
      # Without fuel prices the page and its settings stay out of sight, so
      # the response has no word about it either: a note in every answer of an
      # instance outside the euro would say the same each time. Where the
      # comparison exists but this timeframe has none, a note says why.
      #
      # The amounts are the exact ones of Car::Comparison, rounded by unit.
      # Car::ComparisonAmounts rounds them for the page instead, to whole
      # units for large amounts and with the rest of a sum on one part. So an
      # amount here can differ from the page by about one unit: 116.11 against
      # 117 for a month. The costs per 100 km are the same.
      module Comparison
        module_function

        # The comparison as a hash to splat into the response, empty without
        # fuel prices
        def for(report)
          return {} if report.cars.empty? || !Car::Comparison.available?

          comparison = report.comparison
          note = note(report, comparison)
          return { comparison_note: note } if note

          { comparison: figures(comparison, Car::ComparisonGaps.new(report).to_a) }
        end

        def note(report, comparison)
          if comparison.nil?
            "No comparison with a combustion car: #{without_combustion(report.cars)} " \
              'no fuel or consumption of a combustion car in the settings.'
          elsif !comparison.possible?
            'No comparison with a combustion car: there are no fuel prices for ' \
              'the fuel of each car yet.'
          elsif !comparison.ready?
            'No comparison with a combustion car: no distance to compare in this timeframe.'
          end
        end

        def without_combustion(cars)
          missing = cars.reject(&:combustion?)
          names = missing.map { "car #{it.id} (#{it.display_name})" }.join(', ')
          "#{names} #{missing.one? ? 'has' : 'have'}"
        end

        def figures(comparison, gaps)
          {
            distance_km: Precision.round(comparison.distance, :kilometer),
            **columns(comparison),
            savings: money(comparison.combustion_cost - comparison.car_cost),
            savings_without_pv: money(comparison.combustion_cost - comparison.car_cost_without_pv),
            savings_per_100km: per_100km(comparison, comparison.combustion_cost - comparison.car_cost),
            **(gaps.empty? ? {} : { gaps: gaps.map { gap(it) } }),
          }
        end

        # The three columns of the comparison page, each with its parts
        def columns(comparison)
          {
            car: {
              energy_cost: money(comparison.cost),
              payments: comparison.payment_costs.transform_values { money(it) },
              **total(comparison, comparison.car_cost),
            },
            car_without_pv: { energy_cost: money(comparison.cost_without_pv), **total(comparison, comparison.car_cost_without_pv) },
            combustion: {
              fuel_cost: money(comparison.fuel_cost),
              tax: money(comparison.tax),
              running_costs: money(comparison.shared_cost),
              **total(comparison, comparison.combustion_cost),
            },
          }
        end

        # The total of a column and its cost per 100 km
        def total(comparison, total) = { total: money(total), per_100km: per_100km(comparison, total) }

        # What the comparison lacks (see Car::ComparisonGaps), each with what
        # it does to the numbers
        def gap(gap)
          case gap.key
          when :proposals
            "#{gap.value} offsite charging sessions wait for a confirmation, so their cost is missing."
          when :unrated
            "#{gap.value} km have no cost or no fuel price and are left out on all sides."
          when :splitter
            'Without a power splitter the wallbox has no PV share, so all of its energy costs the grid price.'
          when :payments
            'No payment of the cars in this timeframe, so the running costs hold only the energy and the tax.'
          when :tax
            "No vehicle tax of the combustion car for #{gap.value.map { "car #{it.id}" }.join(', ')}."
          end
        end

        def per_100km(comparison, value) = Precision.round(comparison.per_100km(value), :money_per_100km)
        def money(value) = Precision.round(value, :money)
      end
    end
  end
end
