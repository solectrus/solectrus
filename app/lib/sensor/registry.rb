class Sensor::Registry
  # Simple thread-safe cache using Struct
  CacheStruct =
    Struct.new(:definitions, :definition_hash, :files_loaded) do
      def clear
        self.definitions = nil
        self.definition_hash = nil
        # Don't reset files_loaded to avoid reloading files
      end
    end
  private_constant :CacheStruct

  CACHE = CacheStruct.new
  private_constant :CACHE

  def self.all
    CACHE.definitions ||= load_all_definitions
  end

  def self.[](name)
    unless name.is_a?(Symbol)
      raise ArgumentError, "Sensor name must be a symbol, got #{name.inspect}"
    end

    hash[name] || raise(ArgumentError, "Unknown sensor: #{name}")
  end

  def self.by_category(category)
    all.select { |definition| definition.category == category }.presence ||
      raise(ArgumentError, "Unknown category: #{category}")
  end

  def self.chart_sensors
    all.select(&:chart_enabled?)
  end

  def self.top10_sensors
    all.select(&:top10_enabled?)
  end

  def self.reset!
    CACHE.clear
  end

  def self.hash
    CACHE.definition_hash ||= all.index_by(&:name).freeze
  end
  private_class_method :hash

  def self.load_all_definitions
    # Load all sensor definition files only once
    ensure_definition_files_loaded

    # Auto-discover and instantiate definitions
    definitions =
      Sensor::Definitions
        .constants
        .filter_map { |name| definition_from_constant(name) }
        .flatten

    # Validate uniqueness
    validate_unique_names!(definitions)
    definitions.freeze
  end
  private_class_method :load_all_definitions

  def self.ensure_definition_files_loaded
    return if CACHE.files_loaded

    Rails
      .root
      .glob('app/lib/sensor/definitions/**/*.rb')
      .each { |file| require file }

    CACHE.files_loaded = true
  end
  private_class_method :ensure_definition_files_loaded

  def self.definition_from_constant(const_name)
    return if %i[Base FinanceBase].include?(const_name)

    const = Sensor::Definitions.const_get(const_name)
    return unless const.is_a?(Class) && const < Sensor::Definitions::Base

    instantiate_by_arity(const)
  end
  private_class_method :definition_from_constant

  def self.instantiate_by_arity(const)
    case const.instance_method(:initialize).arity
    when 0
      # Single sensor
      const.new
    when 1
      # Template sensors, MAX constant expected
      (1..const::MAX).map { |i| const.new(i) }
    else
      raise StandardError,
            "#{const.name} has unsupported number of constructor arguments: #{const.instance_method(:initialize).arity}"
    end
  end
  private_class_method :instantiate_by_arity

  def self.validate_unique_names!(definitions)
    duplicates = definitions.group_by(&:name).select { _2.size > 1 }.keys
    return if duplicates.none?

    raise StandardError, "Duplicate sensor definition names: #{duplicates.join(', ')}"
  end
  private_class_method :validate_unique_names!
end
