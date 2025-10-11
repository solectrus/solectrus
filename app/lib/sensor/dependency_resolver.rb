class Sensor::DependencyResolver
  def initialize(sensor_names, context: :unknown)
    @sensor_names = Array(sensor_names)
    @context = context
  end

  attr_reader :sensor_names, :context

  # Kahn's Algorithm: Topological sorting
  #
  # Resolves sensor dependencies using Kahn's algorithm to ensure that
  # dependencies are always processed before their dependents.
  #
  # Algorithm steps:
  # 1. Build dependency graph and calculate in-degrees
  # 2. Start with sensors that have no dependencies (in-degree = 0)
  # 3. Process sensors one by one, removing their outgoing edges
  # 4. When a sensor's in-degree reaches 0, add it to the processing queue
  # 5. Continue until all sensors are processed or a cycle is detected
  #
  # Returns sensors in dependency order: dependencies come before dependents
  def resolve
    # Step 1: Build optimized graph structure
    all_sensors = collect_all_sensors.sort # Sort for deterministic results
    dependency_graph = build_dependency_graph(all_sensors)

    # Step 2: Perform topological sort
    result = perform_topological_sort(all_sensors, dependency_graph)

    # Step 3: Verify no cycles exist
    if result.length == all_sensors.length
      result
    else
      raise ArgumentError,
            "Circular dependency detected in sensors: #{all_sensors - result}"
    end
  end

  # Check if all sensors in this resolver are available (aka "configured")
  def available?
    collect_all_sensors.all? do |sensor_name|
      Sensor::Config.exists?(sensor_name)
    end
  end

  private

  # Performs the main topological sorting algorithm
  def perform_topological_sort(all_sensors, dependency_graph)
    in_degree = dependency_graph[:in_degree]
    dependents = dependency_graph[:dependents]
    result = []

    # Initialize queue with sensors that have no dependencies
    queue = all_sensors.select { |sensor| in_degree[sensor].zero? }
    queue.sort!

    # Process sensors in topological order
    while queue.any?
      sensor_name = queue.shift
      result << sensor_name

      # Update direct dependents
      process_dependents(sensor_name, dependents[sensor_name], in_degree, queue)
    end

    result
  end

  # Updates dependents when a sensor is processed
  def process_dependents(_processed_sensor, dependents_list, in_degree, queue)
    dependents_list.each do |dependent_sensor|
      # Remove the dependency edge
      in_degree[dependent_sensor] -= 1

      # Skip if sensor still has dependencies (in-degree > 0)
      next if in_degree[dependent_sensor].nonzero?

      # Inserts sensor into queue maintaining sorted order
      insert_pos =
        queue.bsearch_index { |x| x > dependent_sensor } || queue.length
      queue.insert(insert_pos, dependent_sensor)
    end
  end

  # Collects all sensors including transitive dependencies
  def collect_all_sensors
    all_sensors = Set.new
    queue = sensor_names.dup

    until queue.empty?
      sensor_name = queue.shift
      next if all_sensors.include?(sensor_name)

      all_sensors << sensor_name

      # Add dependencies to queue for collection
      Sensor::Registry[sensor_name]
        .dependencies(context:)
        .each do |dependency|
          queue << dependency if all_sensors.exclude?(dependency)
        end
    end

    all_sensors.to_a
  end

  # Builds optimized dependency graph with in-degrees and dependent lookups
  # Returns: { in_degree: Hash, dependents: Hash }
  # - in_degree[sensor] = number of dependencies
  # - dependents[sensor] = array of sensors that depend on this sensor
  def build_dependency_graph(all_sensors)
    sensor_set = all_sensors.to_set
    in_degree = Hash.new(0)
    dependents = Hash.new { |h, k| h[k] = [] }

    all_sensors.each do |sensor_name|
      dependencies = Sensor::Registry[sensor_name].dependencies(context:)

      # Count only dependencies that are in our sensor set (excluding self-dependencies)
      in_degree[sensor_name] = dependencies.count do |dep|
        sensor_set.include?(dep) && dep != sensor_name
      end

      # Build reverse lookup: for each dependency, track which sensors depend on it
      dependencies.each do |dependency|
        next if sensor_set.exclude?(dependency)
        next if dependency == sensor_name # Skip self-dependencies

        dependents[dependency] << sensor_name
      end
    end

    { in_degree:, dependents: }
  end
end
