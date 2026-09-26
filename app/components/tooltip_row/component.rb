# A tooltip row that shows a color swatch, a label and the value that belongs
# to it. The value comes from the block. In a calculation, the operator
# (like "+") stands in front of the row. An empty operator keeps its room,
# so the swatches of all rows stand in one column.
class TooltipRow::Component < ViewComponent::Base
  def initialize(label:, color_class: nil, color_var: nil, operator: nil)
    super()
    @label = label
    @color_class = color_class
    @color_var = color_var
    @operator = operator
  end

  attr_reader :label, :color_class, :color_var, :operator

  private

  def swatch_style
    "background: var(#{color_var})" if color_var
  end
end
