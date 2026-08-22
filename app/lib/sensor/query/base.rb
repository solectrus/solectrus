module Sensor
  module Query
    class Base
      def initialize(sensor_names, timeframe)
        @sensor_names = Array(sensor_names)
        @timeframe = timeframe

        validate_sensor_names!
        validate_timeframe!
      end

      attr_reader :sensor_names, :timeframe

      def call(additional_attributes = {})
        raw_data = fetch_raw_data

        # Merge additional attributes into raw_data
        if raw_data.is_a?(Hash)
          raw_data.merge!(additional_attributes)
        elsif raw_data.is_a?(Array)
          # For time series data, add additional attributes to each point
          raw_data.each { |point| point.merge!(additional_attributes) }
        end

        create_data_instance(raw_data, timeframe).tap do |data|
          ensure_sensor_accessors(data)
          process_calculated_sensors(data)
        end
      end

      protected

      def fetch_raw_data
        # simplecov:disable
        raise NotImplementedError, 'Subclasses must implement #fetch_raw_data'
        # simplecov:enable
      end

      def create_data_instance(raw_data, timeframe)
        # simplecov:disable
        raise NotImplementedError,
              'Subclasses must implement #create_data_instance'
        # simplecov:enable
      end

      def required_sensor_names
        @required_sensor_names ||=
          Sensor::DependencyResolver.new(
            sensor_names,
            context: query_type,
          ).resolve
      end

      def validate_sensor_names!
        if sensor_names.empty?
          raise ArgumentError, 'Sensor names cannot be empty'
        end

        # Check if all requested sensors are known
        sensor_names.all? { |name| Sensor::Registry[name] }

        :ok
      end

      def validate_timeframe!
        :ok
      end

      def ensure_sensor_accessors(data)
        # Create accessors for ALL requested sensors, even those with no data
        # This ensures that sensors requested in the query but missing from the results
        # still have accessor methods that return nil (for InfluxDB) or 0 (for SQL)
        required_sensor_names.each do |sensor_name|
          next if data.respond_to?(sensor_name)

          # Create accessor method for all requested sensors
          data.define_singleton_method(sensor_name) do |*args|
            return unless raw_data.key?(sensor_name)

            # Sensor has data - use normal calculation/conversion
            get_sensor_value(sensor_name, args)
          end
        end
      end

      def process_calculated_sensors(data)
        return if calculated_sensors.empty?

        if data.is_a?(Sensor::Data::Series)
          data.points.zip(data.reporting_sensor_names) do |point, names|
            process_calculated_sensors_for_point(point, names)
          end

          calculated_sensors.each do |sensor_name|
            create_series_accessor_for_calculated_sensor(data, sensor_name)
          end
        else
          # Read before the first #store_sensor_value, which publishes the
          # calculated sensors into the very list this asks for.
          process_calculated_sensors_for_point(
            data,
            data.sensor_names_with_values,
          )
        end
      end

      def process_calculated_sensors_for_point(point, sensor_names_with_data)
        # Process in dependency order - DependencyResolver already provides correct order
        calculated_sensors.each do |sensor_name|
          process_single_calculated_sensor(
            point,
            sensor_name,
            sensor_names_with_data,
          )
        end
      end

      def process_single_calculated_sensor(point, sensor_name, sensor_names_with_data)
        sensor = Sensor::Registry[sensor_name]
        return if query_answered_sensor?(point, sensor_name)

        dependency_values = extract_dependency_values(point, sensor)

        # Storing publishes the accessor, so the sensors calculated next can
        # depend on this value (DependencyResolver ordered them accordingly)
        point.store_sensor_value(
          sensor_name,
          calculated_value(sensor, dependency_values, sensor_names_with_data),
        )
      end

      # Seam for queries that calculate sensors the generic `calculate` block
      # doesn't cover, see Helpers::Influx::FinanceCalculation.
      def calculated_value(sensor, dependency_values, sensor_names_with_data)
        sensor.calculate(
          **dependency_values,
          context: query_type,
          sensor_names_with_data:,
        )
      end

      def extract_dependency_values(point, sensor)
        sensor.dependencies(context: query_type).index_with do |dependency_name|
          resolve_dependency_value(point, dependency_name, sensor.name)
        end
      end

      def resolve_dependency_value(point, dependency_name, sensor_name)
        if dependency_name == sensor_name
          # Self-dependency: use the raw value that was loaded from DB/InfluxDB
          # This value should not be overridden by any previous calculation
          point.raw_data[dependency_name]
        elsif point.respond_to?(dependency_name)
          # Regular dependency: use the current value (might be calculated)
          # Only access if the dependency sensor has an accessor method defined
          point.public_send(dependency_name)
        end
        # Dependency sensor not available (not configured or no data) - use nil
      end

      # Whether the query itself already answered for this sensor, in which
      # case the calculate block must not overwrite that answer. An answer is
      # keyed by aggregation, so only a SQL result and Influx::Aggregation
      # can hold one.
      #
      # Series#build_points keys a point by the bare sensor name. That key is
      # gone by the time such a point arrives here, so a series recomputes
      # every calculated sensor. A sensor the summary stores must therefore
      # name its own field as a dependency to get the stored value back.
      # InverterPower.depends_on does that.
      def query_answered_sensor?(point, sensor_name)
        # SQL fills a column for every stored field it was asked for, NULLs
        # included, so only a value counts as an answer. Influx fills its gaps
        # with nil too, but there a key has to count: such a point holds one
        # key per aggregation, and a calculate block reads a dependency
        # without naming one, which raises as soon as there are two.
        key_alone_counts = query_type != :sql

        point.raw_data.any? do |key, value|
          next false unless key.is_a?(Array) && key.first == sensor_name

          key_alone_counts || !value.nil?
        end
      end

      # Rebuilt for every data point otherwise, and the sensors of a query
      # cannot change while it runs.
      def calculated_sensors
        @calculated_sensors ||=
          required_sensor_names.select do |sensor_name|
            should_calculate_sensor?(sensor_name)
          end
      end

      def should_calculate_sensor?(sensor_name)
        Sensor::Registry[sensor_name].calculated?
      end

      # Common method for filtering sensors by availability
      def available_sensors
        @available_sensors ||=
          required_sensor_names.select { |name| sensor_available?(name) }
      end

      def sensor_available?(name)
        Sensor::DependencyResolver.new(name, context: query_type).available?
      end

      # Create a series-level accessor for a calculated sensor: the value each
      # point computed, keyed by the instant that point was built for. Series
      # pairs the two itself, see its #timestamps.
      def create_series_accessor_for_calculated_sensor(data, sensor_name)
        data.define_singleton_method(sensor_name) do |*|
          points.zip(timestamps).to_h do |point, time|
            [time, point.public_send(sensor_name)]
          end
        end
      end

      # Common empty result method - can be overridden by subclasses
      def empty_result
        {}
      end

      # Default query type - subclasses should override
      def query_type
        :unknown
      end
    end
  end
end
