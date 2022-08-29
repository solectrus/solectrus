class Balance::Component < ViewComponent::Base
  renders_many :segments,
               ->(field) { BalanceSegment::Component.new field:, parent: self }

  def initialize(side:, calculator:)
    super
    @side = side
    @calculator = calculator
  end

  attr_reader :calculator, :side

  def existing_segments
    @existing_segments ||= segments.select(&:exist?)
  end

  def title
    I18n.t "balance_sheet.#{side}"
  end
end
