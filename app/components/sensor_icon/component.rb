class SensorIcon::Component < ViewComponent::Base
  def initialize(sensor, context: nil, **options)
    super
    @sensor = sensor.to_sym
    @context = context
    @options = options
  end

  attr_reader :sensor, :context, :options

  def call
    return unless sensor_icon_class

    tag.i(class: icon_class, style: icon_style)
  end

  private

  def icon_class
    ['fa', sensor_icon_class, options[:class]]
  end

  def icon_style
    options[:style]
  end

  def sensor_icon_class # rubocop:disable Metrics/CyclomaticComplexity
    case sensor
    when :grid_export_power, :grid_import_power, :grid_power
      'fa-bolt'
    when :battery_discharging_power, :battery_charging_power, :battery_power,
         :battery_soc
      battery_icon_class
    when :house_power, :house_power_without_custom, :house_power_grid
      'fa-home'
    when :heatpump_power, :heatpump_power_grid
      'fa-fan'
    when :wallbox_power, :wallbox_power_grid
      'fa-car'
    when :savings
      'fa-piggy-bank'
    when :co2_reduction
      'fa-leaf'
    when :inverter_power, *SensorConfig::CUSTOM_INVERTER_SENSORS
      'fa-sun'
    end
  end

  def battery_icon_class
    return 'fa-battery-half' unless battery_soc

    if battery_soc < 15
      'fa-battery-empty'
    elsif battery_soc < 30
      'fa-battery-quarter'
    elsif battery_soc < 60
      'fa-battery-half'
    elsif battery_soc < 85
      'fa-battery-three-quarters'
    else
      'fa-battery-full'
    end
  end

  def battery_soc
    return unless context.respond_to?(:battery_soc)

    context.battery_soc
  end
end
