module Sensor
  # SummaryBuilder handles the data collection logic for the Summarizer.
  # It uses Sensor::Query::Helpers::Influx::Integral and Sensor::Query::Helpers::Influx::Aggregation
  # to collect raw data and returns a single Sensor::Data::Single object.
  class SummaryBuilder # rubocop:disable Metrics/ClassLength
    def initialize(timeframe)
      raise ArgumentError unless timeframe.day?

      @timeframe = timeframe
    end

    attr_reader :timeframe

    def call
      raw_data = collect_all_sensor_data
      calculated_data = collect_calculated_sensor_data(raw_data)

      # Merge raw and calculated data
      all_data = raw_data.merge(calculated_data)

      # Data validation and cleanup
      clean_invalid_sensor_values(all_data)
      apply_value_corrections(all_data)

      Sensor::Data::Single.new(all_data, timeframe:)
    end

    private

    def collect_all_sensor_data
      result = {}

      # Handle sum aggregations separately (uses Integral)
      if needed_aggregations.include?(:sum)
        result.merge!(collect_data_for_aggregation(:sum))
      end

      # Handle all non-sum aggregations in one combined query
      non_sum_aggregations = needed_aggregations - [:sum]
      unless non_sum_aggregations.empty?
        result.merge!(
          collect_combined_non_sum_aggregations(non_sum_aggregations),
        )
      end

      result
    end

    def collect_calculated_sensor_data(raw_data)
      # Create a temporary Data::Single object to access raw data for calculations
      temp_data = Sensor::Data::Single.new(raw_data, timeframe:)

      needed_aggregations.each_with_object({}) do |aggregation_type, result|
        calculated_sensors_for_aggregation(aggregation_type).each do |sensor|
          value = calculate_sensor_value(sensor, aggregation_type, temp_data)
          result[[sensor.name, aggregation_type]] = value if value.present?
        end
      end
    end

    def calculate_sensor_value(sensor, aggregation_type, summary_data)
      # Build dependency data using Array-Key format for the calculated sensor
      dependency_data =
        sensor.dependencies.to_h do |dep_name|
          value = get_dependency_value(dep_name, aggregation_type, summary_data)
          [[dep_name, aggregation_type], value]
        end

      # If the sensor needs access to its own raw value (like house_power),
      # include it in the dependency data - but only if it has raw data available
      if sensor.summary_aggregations.any? && sensor_has_influx_data?(sensor)
        raw_value =
          get_dependency_value(sensor.name, aggregation_type, summary_data)
        dependency_data[[sensor.name, aggregation_type]] = raw_value
      end

      data = Sensor::Data::Single.new(dependency_data, timeframe:)
      # Extract dependency values as explicit parameters (keyword arguments)
      dependency_values =
        sensor.dependencies.index_with do |dependency_name|
          data.public_send(dependency_name)
        end
      sensor.calculate(**dependency_values)
    end

    def get_dependency_value(sensor_name, aggregation_type, summary_data)
      dep_sensor = Sensor::Registry[sensor_name]

      # If dependency is calculated and not stored, calculate it recursively
      if dep_sensor.calculated? && !dep_sensor.store_in_summary?
        calculate_sensor_value(dep_sensor, aggregation_type, summary_data)
      elsif dep_sensor.store_in_summary?
        # Otherwise get it from summary_data (if stored and available)
        # Only try to access if the sensor is actually stored in summary
        summary_data.public_send(sensor_name, aggregation_type)
      end
    end

    def calculated_sensors_for_aggregation(aggregation_type)
      Sensor::Config.sensors.select do |s|
        s.store_in_summary? &&
          s.summary_aggregations.include?(aggregation_type) && s.calculated? &&
          !sensor_has_influx_data?(s)
      end
    end

    def collect_data_for_aggregation(aggregation_type)
      sensors = sensors_for_aggregation(aggregation_type)
      return {} if sensors.empty?

      case aggregation_type
      when :sum
        collect_sum_data(sensors)
      when :max, :min, :avg
        collect_aggregation_data(sensors, aggregation_type)
      end
    end

    def collect_sum_data(sensors)
      # Use Integral query for sum values
      sum_query_result =
        Sensor::Query::Helpers::Influx::Integral.new(
          sensors.map(&:name),
          timeframe,
        ).call

      sensors.to_h do |sensor|
        # Only try to access sensors that have accessor methods defined
        if sum_query_result.respond_to?(sensor.name)
          value = sum_query_result.public_send(sensor.name)
          [[sensor.name, :sum], value]
        else
          # Skip sensors that don't have data (not configured or no data available)
          [[sensor.name, :sum], nil]
        end
      end
    end

    def collect_aggregation_data(sensors, aggregation_type)
      # Use Aggregation query for max/min/avg values
      aggregation_query_result =
        Sensor::Query::Helpers::Influx::Aggregation.new(
          sensors.map(&:name),
          timeframe,
        ).call

      sensors.to_h do |sensor|
        # Only try to access sensors that have accessor methods defined
        if aggregation_query_result.respond_to?(sensor.name)
          value =
            aggregation_query_result.public_send(sensor.name, aggregation_type)
          [[sensor.name, aggregation_type], value]
        else
          # Skip sensors that don't have data (not configured or no data available)
          [[sensor.name, aggregation_type], nil]
        end
      end
    end

    def collect_combined_non_sum_aggregations(aggregation_types)
      all_sensors = collect_sensors_for_aggregation_types(aggregation_types)
      return {} if all_sensors.empty?

      aggregation_query_result = fetch_aggregation_data(all_sensors)
      build_aggregation_result(
        all_sensors,
        aggregation_types,
        aggregation_query_result,
      )
    end

    def collect_sensors_for_aggregation_types(aggregation_types)
      aggregation_types
        .flat_map { |agg_type| sensors_for_aggregation(agg_type) }
        .uniq
    end

    def fetch_aggregation_data(all_sensors)
      Sensor::Query::Helpers::Influx::Aggregation.new(
        all_sensors.map(&:name),
        timeframe,
      ).call
    end

    def build_aggregation_result(all_sensors, aggregation_types, query_result)
      result = {}

      all_sensors.each do |sensor|
        next unless query_result.respond_to?(sensor.name)

        collect_sensor_aggregations(
          sensor,
          aggregation_types,
          query_result,
          result,
        )
      end

      result
    end

    def collect_sensor_aggregations(
      sensor,
      aggregation_types,
      query_result,
      result
    )
      sensor.summary_aggregations.each do |aggregation_type|
        next if should_skip_aggregation?(aggregation_type, aggregation_types)

        value = query_result.public_send(sensor.name, aggregation_type)
        result[[sensor.name, aggregation_type]] = value
      end
    end

    def should_skip_aggregation?(aggregation_type, requested_types)
      aggregation_type == :sum || requested_types.exclude?(aggregation_type)
    end

    def sensors_for_aggregation(aggregation_type)
      case aggregation_type
      when :sum
        watt_sensors_for_sum
      when :max, :min, :avg
        # Only sensors that specifically support this aggregation type
        sensors_for_summary_aggregation(aggregation_type).select do |s|
          sensor_has_influx_data?(s)
        end
      else
        []
      end
    end

    def watt_sensors_for_sum
      # Only sensors that have raw InfluxDB data (includes house_power even if calculated)
      sensors_for_summary_aggregation(:sum).select do |s|
        s.unit == :watt && sensor_has_influx_data?(s)
      end
    end

    def available_aggregation_sensors
      # Only sensors that have raw InfluxDB data for max/min/avg
      Sensor::Config.sensors.select do |s|
        s.store_in_summary? &&
          s.summary_aggregations.intersect?(%i[max min avg]) &&
          sensor_has_influx_data?(s)
      end
    end

    def sensors_for_summary_aggregation(aggregation_type)
      Sensor::Config.sensors.select do |s|
        s.store_in_summary? && s.summary_aggregations.include?(aggregation_type)
      end
    end

    def sensor_has_influx_data?(sensor)
      Sensor::Config.configured?(sensor.name)
    end

    def needed_aggregations
      @needed_aggregations ||=
        Sensor::Config
          .sensors
          .select(&:store_in_summary?)
          .flat_map(&:summary_aggregations)
          .uniq
    end

    # ============================================
    # Data validation and cleanup
    # ============================================

    def clean_invalid_sensor_values(all_data)
      # Create temporary Data::Single object for helper methods
      temp_data = Sensor::Data::Single.new(all_data, timeframe:)
      nullify_sums_without_corresponding_max(temp_data, all_data)
      nullify_grid_sensors_without_base_sensors(temp_data, all_data)
      clamp_values_to_sensor_ranges(all_data)
    end

    # The `integral()` function in InfluxDB returns `0` when no data is available,
    # but we want to store `nil` in this case.
    #
    # We can fix this, because we have the `max` values available, which ARE
    # `nil` when no data is available
    def nullify_sums_without_corresponding_max(summary_data, all_data)
      sensors_with_sum_and_max.each do |sensor|
        sensor_name = sensor.name

        # Check if sensor has both sum and max aggregations available
        has_sum = sensor_aggregation?(summary_data, sensor_name, :sum)
        has_max = sensor_aggregation?(summary_data, sensor_name, :max)

        next unless has_sum && has_max

        # Get max value to check if it's nil
        max_value =
          get_sensor_aggregation_value(summary_data, sensor_name, :max)

        # Nullify sum if max is nil
        if max_value.nil?
          set_sensor_aggregation_value(all_data, sensor_name, :sum, nil)
        end
      end
    end

    # Fix the power-splitter sums in a similar way:
    # Nullify power-splitter sums when there is no corresponding sum value
    def nullify_grid_sensors_without_base_sensors(summary_data, all_data)
      summary_data.sensor_names.each do |sensor_name|
        sensor = Sensor::Registry[sensor_name]
        next unless sensor.category == :power_splitter
        next unless sensor_aggregation?(summary_data, sensor_name, :sum)

        base_sensor_name = sensor.corresponding_base_sensor.name
        base_sum_value =
          get_sensor_aggregation_value(summary_data, base_sensor_name, :sum)

        # Nullify grid sensor sum if base sensor sum is nil or not present
        unless base_sum_value
          set_sensor_aggregation_value(all_data, sensor_name, :sum, nil)
        end
      end
    end

    # Helper methods for working with Sensor::Data::Single objects
    def sensor_aggregation?(summary_data, sensor_name, aggregation)
      summary_data.respond_to?(sensor_name) &&
        summary_data.raw_data.key?([sensor_name, aggregation])
    end

    def get_sensor_aggregation_value(summary_data, sensor_name, aggregation)
      return unless sensor_aggregation?(summary_data, sensor_name, aggregation)

      summary_data.public_send(sensor_name, aggregation)
    end

    def set_sensor_aggregation_value(all_data, sensor_name, aggregation, value)
      # Modify the all_data hash directly
      key = [sensor_name, aggregation]
      all_data[key] = value
    end

    def sensors_with_sum_and_max
      @sensors_with_sum_and_max ||=
        Sensor::Config.sensors.select do |s|
          s.store_in_summary? && s.summary_aggregations.include?(:sum) &&
            s.summary_aggregations.include?(:max)
        end
    end

    # ============================================
    # Value correction
    # ============================================

    def apply_value_corrections(all_data)
      # Create temporary Data::Single object for helper methods
      temp_data = Sensor::Data::Single.new(all_data, timeframe:)

      sensors = main_consumer_sensors + [Sensor::Registry[:grid_import_power]]
      apply_correction_to_sensors(sensors, temp_data, all_data)

      sensors = custom_consumer_sensors
      apply_correction_to_sensors(sensors, temp_data, all_data)
    end

    def apply_correction_to_sensors(sensors, _summary_data, all_data)
      existing_sensors = filter_existing_sensors(sensors, all_data)
      return if existing_sensors.empty?

      corrector_input = build_corrector_input(existing_sensors, all_data)
      return if corrector_input.empty?

      apply_corrections(corrector_input, all_data)
    end

    def filter_existing_sensors(sensors, all_data)
      return [] if sensors.empty?

      sensors.select { |sensor| all_data.key?([sensor.name, :sum]) }
    end

    def build_corrector_input(existing_sensors, all_data)
      corrector_input = {}
      existing_sensors.each do |sensor|
        sum_value = all_data[[sensor.name, :sum]]
        corrector_input[sensor.name] = sum_value if sum_value.present?
      end
      corrector_input
    end

    def apply_corrections(corrector_input, all_data)
      corrector = SummaryCorrector.new(corrector_input)

      corrector.adjusted.each do |sensor_name, corrected_value|
        set_sensor_aggregation_value(
          all_data,
          sensor_name,
          :sum,
          corrected_value,
        )
      end
    end

    # ============================================
    # Sensor name collections
    # ============================================

    def main_consumer_sensors
      @main_consumer_sensors ||= calculate_main_consumer_sensors
    end

    def calculate_main_consumer_sensors
      base_sensors = [
        Sensor::Registry[:house_power],
        Sensor::Registry[:heatpump_power],
        Sensor::Registry[:wallbox_power],
        Sensor::Registry[:battery_charging_power],
      ]

      power_sensors =
        base_sensors +
          (Sensor::Config.house_power_excluded_custom_sensors || [])

      add_corresponding_grid_sensors(power_sensors)
    end

    def custom_consumer_sensors
      @custom_consumer_sensors ||= calculate_custom_consumer_sensors
    end

    def calculate_custom_consumer_sensors
      all_custom_power_sensor =
        (Sensor::Config.sensors || []).grep(Sensor::Definitions::CustomPower)
      excluded_sensors = Sensor::Config.house_power_excluded_sensors || []

      included_custom_sensors =
        all_custom_power_sensor.select do |sensor|
          excluded_sensors.exclude?(sensor)
        end

      add_corresponding_grid_sensors(included_custom_sensors)
    end

    def add_corresponding_grid_sensors(power_sensors)
      grid_sensors =
        power_sensors.filter_map do |sensor|
          grid_sensor_name = :"#{sensor.name}_grid"
          Sensor::Registry[grid_sensor_name]
        end

      power_sensors + grid_sensors
    end

    # Clamp sensor values to their defined valid ranges
    # This ensures physically impossible values (like negative power generation) are corrected
    def clamp_values_to_sensor_ranges(all_data)
      all_data.each do |(sensor_name, aggregation), value|
        sensor = Sensor::Registry[sensor_name]
        all_data[[sensor_name, aggregation]] = sensor.clamp_value(value)
      end
    end
  end
end
