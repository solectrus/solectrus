# A row of a calculation in a tooltip, as a `dt` and a `dd`, so it belongs in
# a `dl`: the operator and the label, and the value from the block. A row with
# "=" is the result of its step, and the group draws the line above it. The
# total is the final result, which stands out (tooltip_content.css).
class CalcRow::Component < ViewComponent::Base
  OPERATORS = { plus: '+', minus: '−', divide: '÷', equals: '=' }.freeze
  private_constant :OPERATORS

  NO_BREAK_SPACE = "\u00A0".freeze
  private_constant :NO_BREAK_SPACE

  def initialize(label:, operator: nil, total: false)
    super()
    @label = label
    @operator = operator
    @total = total
  end

  attr_reader :label

  def row_class
    [
      'label-value-row',
      ('tooltip-result' if @operator == :equals),
      ('tooltip-total' if @total),
    ]
  end

  def operator_prefix
    "#{OPERATORS[@operator]}#{NO_BREAK_SPACE}" if @operator
  end
end
