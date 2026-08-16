class Sensor::Definitions::Base # rubocop:disable Metrics/ClassLength
  include Sensor::Definitions::Dsl
  # display_name / description / canonical_label and their derivation logic
  include Sensor::Definitions::Describable

  delegate :value_range,
           :summary_aggregations,
           :allowed_aggregations,
           :summary_meta_aggregations,
           :trend_aggregation,
           :max_age,
           to: :class

  def initialize
    validate_unit!
  end

  def name
    class_name = self.class.name
    return :anonymous if class_name.nil?

    class_name.demodulize.underscore.to_sym
  end

  def unit
    self.class.unit || raise(NotImplementedError, 'Subclass must define unit')
  end

  # Natural aggregation for this sensor based on its unit, falling back to
  # whatever the sensor actually supports. Energy/money/CO2 are summed
  # (integral over time), percentages and temperatures averaged.
  def default_aggregation
    preferred =
      case unit
      when :watt, :money, :money_per_kwh, :gram then :sum
      when :percent, :celsius then :avg
      end

    return preferred if preferred && allowed_aggregations.include?(preferred)

    allowed_aggregations.first
  end

  # Decimals needed to show a value the way it was measured, for places that
  # must not round (tooltips). Comes with the unit; a sensor may override it.
  def exact_precision
    Sensor::Units[unit].exact_precision
  end

  def color_background(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    return data[:background] if data

    scale = self.class.meta_data[:color_background_scale]
    return color_class_for_value(scale, value) if scale && !value.nil?

    evaluate_config_value(:color_background)
  end

  def color_text(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    data ? data[:text] : evaluate_config_value(:color_text)
  end

  def color_border(index: nil, value: nil)
    data = color_data_dynamic(index:, value:)
    data ? data[:border] : evaluate_config_value(:color_border)
  end

  def color_scale
    scale = self.class.meta_data[:color_background_scale]
    return unless scale&.any?

    scale.map { |value, classes| { value:, colorClass: classes } }
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

  def forecast?
    category == :forecast
  end

  # Whether this sensor carries a meaningful reading of a single INSTANT.
  #
  # The power splitters do not. The Power Splitter service recomputes the
  # grid/PV division on its own cycle of several minutes and writes one value
  # per cycle, so that value divides a PERIOD rather than reading a moment.
  # Pairing it with a base sensor sampled seconds ago mixes two states of the
  # system, and their difference can then exceed the whole. The declared range
  # floors that at 0, so the mix reads as a plausible zero rather than as an
  # impossible negative - which is worse, not better, and is why the live
  # reading is withheld instead of repaired.
  #
  # This is about the instant, not about resolution: once a window is over,
  # every cycle inside it has been written and the division is exact, so a
  # completed day splits as faithfully as a completed year. What a split can
  # never answer is "right now" - and that is what every "now" view in the UI
  # has always hidden. Stating it once keeps the next caller from rediscovering
  # it the hard way.
  def instantaneous?
    category != :power_splitter
  end

  def chart_enabled?
    self.class.meta_data[:chart].present?
  end

  # The names a page offers for this chart. Usually the name of the sensor
  # itself, but a combined chart is offered as each of its halves, and each
  # half is what the URL then carries (see the `chart` DSL).
  def chart_entry_names
    @chart_entry_names ||=
      self.class.meta_data.dig(:chart, :entries) || [name].freeze
  end

  # The entry names of this chart other than `of`. Asked of a half, that is
  # the other half. Asked of the combined sensor itself, both halves, because
  # it is never one of its own entries. Asked of a plain sensor, none.
  def chart_partner_names(of = name) = chart_entry_names - [of]

  # The home pages that show this sensor (see the `home_pages` DSL). A sensor
  # whose pages depend on the settings declares a block, and it runs here.
  def home_pages
    evaluate_config_value(:home_pages, default: [])
  end

  # Whether this sensor only feeds a chart and never carries a scalar value of
  # its own (see the `chart_only` DSL). Any tool reporting single values has to
  # say so instead of returning a null that reads as an outage.
  def chart_only?
    self.class.meta_data[:chart_only].present?
  end

  def chart(timeframe, **)
    config = self.class.meta_data[:chart]
    return unless config

    instance_exec(timeframe, **, &config[:block])
  end

  def top10_enabled?
    evaluate_config_value(:top10_enabled, default: false)
  end

  def top10_permitted?
    block = self.class.inherited_meta_data(:top10_permitted)
    return true unless block

    instance_exec(&block)
  end

  def nameable?
    evaluate_config_value(:nameable, default: false)
  end

  def trendable?
    self.class.trendable
  end

  def hatch_fill?
    self.class.meta_data.fetch(:hatch_fill, false)
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

  # Static dependencies only (no Proc evaluation, safe for recursive checks)
  def static_dependencies
    deps = self.class.depends_on
    deps.is_a?(Proc) ? [] : Array(deps)
  end

  def store_in_summary?
    summary_aggregations.any?
  end

  # The summary_values fields this sensor ultimately resolves to: itself when it
  # is stored, otherwise the stored fields of its (transitive) SQL dependencies.
  # Used to build ranking CTEs and derived SQL calculations.
  def storable_fields(visited = Set.new)
    return [name] if store_in_summary?
    return [] if visited.include?(name)

    dependencies(context: :sql)
      .flat_map { |dep| Sensor::Registry[dep].storable_fields(visited + [name]) }
      .uniq
  end

  # Ratio sensors compute their SQL over daily CTE rows. For period rankings the
  # daily rows are summed before the ratio is taken, so a field expression must
  # be wrapped in SUM(); for daily rankings it is used as-is.
  def sql_sum(expr, period:)
    period ? "SUM(#{expr})" : expr
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

  # Whether a ranking of this sensor rests on something the summaries actually
  # hold. A ranking orders periods by a value it reads out of summary_values,
  # so it needs either a stored field of its own or a SQL expression deriving
  # one.
  #
  # A sensor with neither is assembled in Ruby from OTHER sensors' fields, and
  # the ranking query can only guess at what it does with them: it adds them
  # up. That is right for a sensor that really is their sum (total_consumption,
  # custom_power_total) and wrong for every other shape - house_power_without_custom
  # subtracts its custom sensors, each _pv split subtracts its _grid half,
  # grid_balance nets revenue against costs. The guess cannot tell the two
  # apart, so nothing outside the summaries counts as rankable.
  def rankable?
    store_in_summary? || sql_calculated?
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

  def color_class_for_value(scale, value)
    return scale.last&.last if value.nil?

    sorted = scale.sort_by(&:first)
    min_value, min_class = sorted.first
    max_value, max_class = sorted.last
    return min_class if value <= min_value
    return max_class if value >= max_value

    nearest_scale_class(sorted, value)
  end

  def nearest_scale_class(sorted, value)
    sorted.min_by { |entry_value, _| (entry_value - value).abs }&.last
  end

  def validate_unit!
    return if Sensor::Units.names.include?(unit)

    raise ArgumentError,
          "Invalid unit #{unit.inspect} for sensor #{name.inspect}. " \
            "Must be one of: #{Sensor::Units.names.join(', ')}"
  end
end
