class Top10CalcSelect::Component < ViewComponent::Base
  def initialize(calc:)
    super()
    @calc = ActiveSupport::StringInquirer.new(calc)
  end

  attr_reader :calc
end
