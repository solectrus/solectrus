class InfoTooltip::Component < ViewComponent::Base
  def initialize(text:, placement: 'bottom')
    super()
    @text = text
    @placement = placement
  end

  attr_reader :text, :placement

  # Split the hint into paragraphs on blank lines (\n\n), so longer hints stay
  # readable inside the tooltip.
  def paragraphs
    safe_join(
      text.to_s.split("\n\n").map.with_index do |paragraph, index|
        tag.p(paragraph, class: ('mt-2' if index.nonzero?))
      end,
    )
  end
end
