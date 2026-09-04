# A tooltip row that shows a color swatch, a label and the value that belongs
# to it. The value comes from the block.
class TooltipRow::Component < ViewComponent::Base
  def initialize(label:, color_class: nil, color_var: nil)
    super()
    @label = label
    @color_class = color_class
    @color_var = color_var
  end

  attr_reader :label, :color_class, :color_var

  private

  def swatch_style
    "background: var(#{color_var})" if color_var
  end
end
