class ChartDropdownBase::Component < ViewComponent::Base
  SEPARATOR = :_
  private_constant :SEPARATOR

  def initialize(sensor_name:, timeframe:)
    super()
    @sensor_name = sensor_name
    @timeframe = timeframe
  end

  attr_reader :sensor_name, :timeframe

  def call
    render(
      ChartSelector::Component.new(
        sensor_name:,
        timeframe:,
        sensor_names:,
        menu_config:,
      ),
    )
  end

  private

  def menu_config
    { items: filtered_menu_items }
  end

  def filtered_menu_items
    sanitize_menu_items(select_available_menu_items)
  end

  def select_available_menu_items
    menu_items.select { |item| separator?(item) || sensor_names.include?(item) }
  end

  def sanitize_menu_items(items)
    sanitized = []
    items.each do |item|
      next if duplicate_separator?(item, sanitized)

      sanitized << item
    end

    remove_trailing_separator(sanitized)
  end

  def duplicate_separator?(item, sanitized)
    separator?(item) && (sanitized.empty? || separator?(sanitized.last))
  end

  def remove_trailing_separator(items)
    items.pop if items.last && separator?(items.last)
    items
  end

  def separator?(item)
    item == SEPARATOR
  end

  def sensor_names
    @sensor_names ||= Sensor::Config.chart_sensors.filter_map { |sensor| sensor.name if include_sensor?(sensor) }
  end

  def include_sensor?(sensor)
    menu_items.include?(sensor.name)
  end

  # Subclasses override to define menu order and separators.
  def menu_items
    []
  end
end
