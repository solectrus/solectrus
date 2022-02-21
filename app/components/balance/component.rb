class Balance::Component < ViewComponent::Base
  renders_many :segments,
               ->(field) {
                 BalanceSegment::Component.new field:, parent: self
               }

  def initialize(title:, calculator:)
    super
    @title = title
    @calculator = calculator
  end

  attr_reader :title, :calculator

  def existing_segments
    @existing_segments ||= segments.select(&:exist?)
  end
end
