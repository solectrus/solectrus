class BalanceSegment::Component < ViewComponent::Base
  def initialize(field:, parent:, peak:)
    super
    @field = field
    @peak = peak
    @parent = parent
  end

  attr_reader :field, :parent, :peak

  delegate :calculator, to: :parent

  def url
    root_path(
      field: field.to_s.sub(/_plus|_minus/, ''),
      timeframe: parent.timeframe,
    )
  end

  def value
    @value ||= calculator.public_send(field).to_f
  end

  def percent
    @percent ||= calculator.public_send(:"#{field}_percent").to_f
  end

  def now?
    parent.timeframe.now?
  end

  def masked_value
    unsigned_value = field.to_s.include?('power') ? value / 1_000.0 : value

    case field
    when :grid_power_plus, :bat_power_minus
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
    case field
    when :grid_power_minus, :grid_power_plus
      'fa-bolt'
    when :inverter_power
      'fa-sun'
    when :bat_power_minus, :bat_power_plus
      battery_class
    when :house_power
      'fa-home'
    when :wallbox_charge_power
      'fa-car'
    end
  end

  def battery_class
    unless calculator.respond_to?(:bat_fuel_charge) &&
             calculator.bat_fuel_charge
      return 'fa-battery-half'
    end

    if calculator.bat_fuel_charge < 15
      'fa-battery-empty'
    elsif calculator.bat_fuel_charge < 30
      'fa-battery-quarter'
    elsif calculator.bat_fuel_charge < 60
      'fa-battery-half'
    elsif calculator.bat_fuel_charge < 85
      'fa-battery-three-quarters'
    else
      'fa-battery-full'
    end
  end

  def color_class
    case field
    when :grid_power_minus, :inverter_power
      'bg-green-600'
    when :bat_power_minus, :bat_power_plus
      'bg-green-700'
    when :house_power
      'bg-slate-500'
    when :wallbox_charge_power
      'bg-slate-600'
    when :grid_power_plus
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
