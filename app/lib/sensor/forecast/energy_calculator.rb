module Sensor
  module Forecast
    # Calculates energy (Wh) from power measurements using numerical integration
    # Uses left endpoint rule (left Riemann sum): Energy = sum(Power_i * delta_t_i)
    class EnergyCalculator
      class << self
        # Calculate total energy (Wh) from power measurements
        def calculate_wh(entries)
          return 0 if entries.size < 2

          sum_energy_intervals(entries)
        end

        private

        def sum_energy_intervals(entries)
          entries
            .sort_by(&:first) # Ensure chronological order
            .each_cons(2)
            .sum { |(t1, power), (t2, _)| energy_for_interval(t1, t2, power) }
        end

        def energy_for_interval(start_time, end_time, power_watts)
          return 0 if power_watts.nil?

          interval_hours = (end_time - start_time) / 3600.0
          power_watts * interval_hours # Wh for this interval
        end
      end
    end
  end
end
