module Sensor
  module Forecast
    # Calculates energy (kWh) from power measurements using numerical integration
    # Uses left endpoint rule (left Riemann sum): Energy = sum(Power_i * delta_t_i)
    class EnergyCalculator
      class << self
        # Calculate total energy (kWh) from power measurements
        def calculate_kwh(entries)
          return 0 if entries.size < 2

          total_wh = sum_energy_intervals(entries)
          (total_wh / 1000.0).round # Convert Wh to kWh
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
