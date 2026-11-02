# A figure of the car page, like the charged energy or a rate, which loads
# its chart, or with `href` opens a page, like the comparison with a
# combustion car (see Car::FigureTag). The tooltip names the figure with its
# `title`, which a screen reader reads beside the value, with its `icon`
# above it, and says in its `description` what the value counts. It has the
# `parts` of the value, like the cost of each source (see
# Car::Tooltip::Component::Part), the `bar` of a span (see
# Car::SpanBar::Component), and the paragraphs of its `notes`, like how the
# value comes about.
Car::Figure = Data.define(:sensor_name, :value, :href, :title, :description, :bar, :parts, :notes, :icon) do
  def initialize(href: nil, title: nil, description: nil, bar: nil, parts: [], notes: [], icon: nil, **) = super # rubocop:disable Metrics/ParameterLists

  def tooltip? = title.present? || parts.any? || notes.any?
end
