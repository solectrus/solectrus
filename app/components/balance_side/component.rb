class BalanceSide::Component < ViewComponent::Base
  renders_many :segments,
               ->(sensor, peak = nil) do
                 if Rails.application.config.x.influx.sensors.exists?(sensor)
                   BalanceSegment::Component.new sensor:, peak:, parent: self
                 end
               end

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
end
