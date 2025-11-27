class Sensor::Definitions::Base
  include Sensor::Definitions::Dsl

  # Allowed unit types
  VALID_UNITS = %i[
    watt
    celsius
    percent
    unitless
    boolean
    string
    gram
    euro
    euro_per_kwh
  ].freeze
  private_constant :VALID_UNITS

  delegate :value_range,
           :summary_aggregations,
           :allowed_aggregations,
           :summary_meta_aggregations,
           :trend_aggregation,
           to: :class

  def initialize
    validate_unit!
  end

  def name
    class_name = self.class.name
    return :anonymous if class_name.nil?

    class_name.demodulize.underscore.to_sym
  end

  def display_name(format = :long)
    # 1. User-defined names have priority
    name_from_settings = Setting.sensor_names[name].presence
    return name_from_settings if name_from_settings

    # 2. I18n-based
    if %i[short long].exclude?(format)
      raise ArgumentError, "Unknown display name format: #{format}"
    end

    key = format == :short ? "sensors.#{name}_short" : "sensors.#{name}"
    I18n.t(
      key,
      default:
        (
          if format == :short
            I18n.t("sensors.#{name}", default: name.to_s)
          else
            name.to_s
          end
        ),
    ).html_safe
  end

  def unit
    self.class.unit || raise(NotImplementedError, 'Subclass must define unit')
  end

  def color_hex(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    data ? data[:hex] : evaluate_config_value(:color_hex)
  end

  def color_bg(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    data ? data[:bg] : evaluate_config_value(:color_bg)
  end

  def color_text(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    data ? data[:text] : evaluate_config_value(:color_text)
  end

  def color_border(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    data ? data[:border] : evaluate_config_value(:color_border)
  end

  def icon(data: nil)
    icon_config = self.class.meta_data[:icon]
    return unless icon_config

    if icon_config.is_a?(Proc)
      # Block expects data as parameter
      icon_config.call(data)
    else
      # Static string
      icon_config
    end
  end

  def category
    self.class.meta_data.fetch(:category, :other)
  end

  def chart_enabled?
    respond_to?(:chart)
  end

  def top10_enabled?
    evaluate_config_value(:top10_enabled, default: false)
  end

  def nameable?
    evaluate_config_value(:nameable, default: false)
  end

  def trendable?
    self.class.trendable
  end

  def more_is_better?
    self.class.more_is_better
  end

  # Clamp a value to the sensor's valid range
  def clamp_value(value)
    return value unless value.is_a?(Numeric)
    return value if value_range.nil? || value_range.cover?(value)

    # Handle endless ranges
    min_value = value_range.begin
    max_value = value_range.end

    return [value, min_value].max if max_value.nil? # Endless range like (0..)
    return [value, max_value].min if min_value.nil? # Beginless range like (..100)

    value.clamp(min_value, max_value)
  end

  # Dependencies - all required sensors (Raw + Calculation)
  def dependencies(**)
    deps = self.class.depends_on
    deps = instance_exec(**, &deps) if deps.is_a?(Proc)
    Array(deps)
  end

  def store_in_summary?
    summary_aggregations.any?
  end

  def permitted?
    evaluate_config_value(:permitted, default: true)
  end

  def calculated?
    self.class.calculated? || respond_to?(:calculate, true)
  end

  # Returns the sensor name for grid costs (e.g., :house_costs_grid)
  def costs_grid_sensor_name = nil

  # Returns the sensor name for PV/opportunity costs (e.g., :house_costs_pv)
  def costs_pv_sensor_name = nil

  def sql_calculated?
    respond_to?(:sql_calculation)
  end

  def configured?
    Sensor::Config.exists?(name)
  end

  private

  # Cache dynamic color hash (evaluated only once per instance per cache key)
  def color_data_dynamic(index: nil, value: nil)
    @color_data_dynamic_cache ||= {}
    cache_key = [index, value].compact.presence || :default

    if @color_data_dynamic_cache.key?(cache_key)
      return @color_data_dynamic_cache[cache_key]
    end

    block = self.class.meta_data[:color_dynamic]
    @color_data_dynamic_cache[cache_key] = (
      if block
        # Pass the appropriate parameter: value takes precedence over index
        param = value.nil? ? index : value
        instance_exec(param, &block)
      end
    )
  end

  # Evaluate config value - handles both static value and Proc
  def evaluate_config_value(key, default: nil)
    value = self.class.meta_data.fetch(key, default)
    value.is_a?(Proc) ? instance_exec(&value) : value
  end

  def validate_unit!
    return if VALID_UNITS.include?(unit)

    raise ArgumentError,
          "Invalid unit #{unit.inspect} for sensor #{name.inspect}. " \
            "Must be one of: #{VALID_UNITS.join(', ')}"
  end
end
