class EssentialsTile::Component < ViewComponent::Base
  def initialize(calculator:, field:, timeframe:)
    super
    @calculator = calculator
    @field = field.to_sym
    @timeframe = timeframe
  end

  attr_reader :calculator, :field, :timeframe

  def path
    if field.in? %i[savings co2_savings]
      # Currently, there is no chart for savings, so link to inverter_power chart
      root_path(field: 'inverter_power', timeframe:)
    else
      root_path(field:, timeframe:)
    end
  end

  def value
    @value ||= calculator.public_send(field)
  end

  def color
    return :gray if value.nil? || value.round.zero?

    case field
    when :savings, :co2_savings
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

  ICONS = {
    grid_power_minus: 'fa-bolt',
    grid_power_plus: 'fa-bolt',
    inverter_power: 'fa-sun',
    house_power: 'fa-home',
    wallbox_charge_power: 'fa-car',
    savings: 'fa-piggy-bank',
    co2_savings: 'fa-tree-city',
    bat_fuel_charge: 'fa-battery-half',
  }.freeze

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
  private_constant :ICONS

  def icon_class
    ICONS[field]
  end

  def formatted_value
    return '---' unless value

    number = Number::Component.new(value:)
    case field
    when :savings
      number.to_eur(klass: 'text-inherit')
    when :co2_savings
      number.to_weight
    when :autarky, :bat_fuel_charge
      number.to_percent(klass: 'text-inherit')
    else
      timeframe.now? ? number.to_watt : number.to_watt_hour
    end
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
