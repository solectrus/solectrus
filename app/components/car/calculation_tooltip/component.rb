# A tooltip of the car page with a written calculation: the terms, one in
# each row with its operator, a line, and the result. The notes below explain
# it. Without terms, the tooltip shows its notes alone.
class Car::CalculationTooltip::Component < ViewComponent::Base
  # A row of the calculation. The operator is nil for the first term, and the
  # value is a component.
  Row = Data.define(:operator, :label, :value)
  public_constant :Row

  def initialize(notes:, terms: [], result: nil)
    super()
    @terms = terms
    @result = result
    @notes = notes
  end

  attr_reader :terms, :result, :notes
end
