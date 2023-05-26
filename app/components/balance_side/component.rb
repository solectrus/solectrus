class BalanceSide::Component < ViewComponent::Base
  renders_many :segments,
               ->(field, peak = nil) {
                 BalanceSegment::Component.new field:, peak:, parent: self
               }

  def initialize(side:, calculator:, timeframe:)
    super
    @side = side
    @calculator = calculator
    @timeframe = timeframe
  end

  attr_reader :calculator, :side, :timeframe

  def title
    I18n.t "balance_sheet.#{side}"
  end
end
