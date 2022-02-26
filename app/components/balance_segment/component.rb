class BalanceSegment::Component < ViewComponent::Base
  def initialize(field:, parent:)
    super
    @field = field
    @parent = parent
  end

  attr_reader :field, :parent
  attr_accessor :index

  delegate :calculator, to: :parent

  def first?
    index.zero?
  end

  def last?
    index == parent.existing_segments.size - 1
  end

  def value
    @value ||= calculator.public_send(field)
  end

  def percent
    @percent ||= calculator.public_send(:"#{field}_percent")
  end

  def border_class
    [].tap do |result|
      result << 'rounded-t-lg' if first?
      result << 'rounded-b-lg' if last?
    end
  end

  def now?
    params[:period] == 'now'
  end

  def current_value?
    now? && params[:field] == field.to_s
  end

  def masked_value
    field.to_s.include?('power') ? value / 1_000.0 : value
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
    return 'fa-battery-half' unless calculator.respond_to?(:bat_fuel_charge)

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

  def exist?
    percent.positive?
  end
end
