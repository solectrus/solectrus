class EssentialsTile::Component < ViewComponent::Base
  def initialize(field:, timeframe:)
    super
    @field = field.to_sym
    @timeframe = timeframe
  end

  attr_reader :field, :timeframe

  def path
    root_path(field:, timeframe:)
  end

  def value
    @value ||= calculator.public_send(field)
  end

  def color
    case field
    when :savings
      :blue
    when :house_power
      :gray
    else
      :green
    end
  end

  def background_color
    BACKGROUND_COLOR[color]
  end

  def text_primary_color
    TEXT_PRIMARY_COLOR
  end

  def text_secondary_color
    TEXT_SECONDARY_COLOR[color]
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

  BACKGROUND_COLOR = {
    green: 'bg-green-600',
    yellow: 'bg-yellow-600',
    red: 'bg-red-600',
    gray: 'bg-gray-600',
    blue: 'bg-blue-600',
  }.freeze

  TEXT_PRIMARY_COLOR = 'text-white'.freeze

  TEXT_SECONDARY_COLOR = {
    green: 'text-green-100',
    yellow: 'text-yellow-100',
    red: 'text-red-100',
    gray: 'text-gray-100',
    blue: 'text-blue-100',
  }.freeze

  private_constant :BACKGROUND_COLOR
  private_constant :TEXT_PRIMARY_COLOR
  private_constant :TEXT_SECONDARY_COLOR

  def formatted_value
    number = Number::Component.new(value:)

    case field
    when :savings
      number.to_eur(klass: 'text-inherit')
    when :autarky, :bat_fuel_charge
      number.to_percent(klass: 'text-inherit')
    else
      timeframe.now? ? number.to_watt : number.to_watt_hour
    end
  end

  def calculator
    @calculator ||=
      (timeframe.now? ? Calculator::Now.new : Calculator::Range.new(timeframe))
  end

  def refresh_interval
    [
      interval_by_timeframe,
      Rails.configuration.x.influx.poll_interval.seconds,
    ].max
  end

  def interval_by_timeframe
    if timeframe.now?
      5.seconds
    elsif timeframe.day?
      1.minute
    elsif timeframe.week?
      5.minutes
    elsif timeframe.month?
      10.minutes
    elsif timeframe.year?
      1.hour
    else
      1.day
    end
  end
end
