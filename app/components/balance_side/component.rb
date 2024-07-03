class BalanceSide::Component < ViewComponent::Base
  renders_many :segments,
               lambda { |sensor, peak = nil|
                 if render_segment?(sensor)
                   BalanceSegment::Component.new sensor:, peak:, parent: self
                 end
               }

  def initialize(side:, calculator:, timeframe:, sensor:)
    super
    @side = side
    @calculator = calculator
    @timeframe = timeframe
    @sensor = sensor
  end

  attr_reader :calculator, :side, :timeframe, :sensor

  def title
    I18n.t "balance_sheet.#{side}"
  end

  private

  def render_segment?(sensor)
    # We never want a segment for a non-existing sensor
    return false unless SensorConfig.x.exists?(sensor)

    # On the "now" page the height is animated, so
    # we need to render even if the value is curently zero
    return true if timeframe.now?

    # Otherwise, we don't need a segment when value is zero
    calculator.public_send(sensor).nonzero?
  end
end
