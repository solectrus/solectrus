class Balance::Component < ViewComponent::Base
  renders_many :segments,
               ->(field, peak = nil) {
                 BalanceSegment::Component.new field:, peak:, parent: self
               }

  def initialize(side:, calculator:, period:, timestamp: nil)
    super
    @side = side
    @calculator = calculator
    @period = period
    @timestamp = timestamp
  end

  attr_reader :calculator, :side, :period, :timestamp

  def title
    I18n.t "balance_sheet.#{side}"
  end
end
