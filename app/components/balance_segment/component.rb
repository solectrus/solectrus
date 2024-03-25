class BalanceSegment::Component < ViewComponent::Base
  def initialize(sensor:, parent:, peak:)
    super
    @sensor = sensor
    @peak = peak
    @parent = parent
  end

  attr_reader :sensor, :parent, :peak

  delegate :calculator, to: :parent

  def url
    root_path(
      sensor: sensor.to_s.sub(/_import|_export|_charging|_discharging/, ''),
      timeframe: parent.timeframe,
    )
  end

  def value
    @value ||= calculator.public_send(sensor).to_f
  end

  def percent
    @percent ||= calculator.public_send(:"#{sensor}_percent").to_f
  end

  def now?
    parent.timeframe.now?
  end

  def masked_value
    unsigned_value = sensor.to_s.include?('power') ? value / 1_000.0 : value

    case sensor
    when :grid_import_power, :battery_discharging_power
      -unsigned_value
    else
      unsigned_value
    end
  end

  def icon_size
    return 100 if peak.nil?

    Scale.new(target: 80..300, max: peak).result(value)
  end

  def icon_class
    case sensor
    when :grid_export_power, :grid_import_power
      'fa-bolt'
    when :inverter_power
      'fa-sun'
    when :battery_discharging_power, :battery_charging_power
      battery_class
    when :house_power
      'fa-home'
    when :heatpump_power
      'fa-fan'
    when :wallbox_power
      'fa-car'
    end
  end

  def battery_class
    unless calculator.respond_to?(:battery_soc) && calculator.battery_soc
      return 'fa-battery-half'
    end

    if calculator.battery_soc < 15
      'fa-battery-empty'
    elsif calculator.battery_soc < 30
      'fa-battery-quarter'
    elsif calculator.battery_soc < 60
      'fa-battery-half'
    elsif calculator.battery_soc < 85
      'fa-battery-three-quarters'
    else
      'fa-battery-full'
    end
  end

  def color_class
    case sensor
    when :grid_export_power, :inverter_power
      'bg-green-600'
    when :battery_discharging_power, :battery_charging_power
      'bg-green-700'
    when :house_power
      'bg-slate-500'
    when :wallbox_power
      'bg-slate-700'
    when :heatpump_power
      'bg-slate-600'
    when :grid_import_power
      'bg-red-600'
    end
  end

  def font_size(max:)
    return 0 if percent < 6

    [percent + 90, max].min
  end

  def big?
    percent > 33
  end
end
