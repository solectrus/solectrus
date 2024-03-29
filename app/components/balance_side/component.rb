class BalanceSide::Component < ViewComponent::Base
  renders_many :segments,
               ->(field, peak = nil) do
                 BalanceSegment::Component.new field:, peak:, parent: self
               end

  def initialize(side:, calculator:, timeframe:, field:)
    super
    @side = side
    @calculator = calculator
    @timeframe = timeframe
    @field = field
  end

  attr_reader :calculator, :side, :timeframe, :field

  def title
    I18n.t "balance_sheet.#{side}"
  end
end
