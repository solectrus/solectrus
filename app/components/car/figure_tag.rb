# A figure of the car page (see Car::Figure) as a link that loads its chart
# in place (see Car::ChartLink) or opens its page, with its tooltip. The
# component needs a timeframe, like Car::ChartLink.
module Car::FigureTag
  include Car::ChartLink

  private

  # The tag and the options of a figure that loads the chart of its sensor
  # or opens its page, or of a plain block where the chart cannot draw the
  # timeframe or the selection. A figure with a tooltip has it below (see
  # Car::Tooltip::Component). A tap on a link opens it, so its tooltip
  # needs a long press. A press scales the content alone (see #press_class).
  # `link_class` applies to a link alone, like its hover, and `placement`
  # places the tooltip, like beside the lead.
  def figure_tag(figure, link_class: nil, placement: nil, **options, &)
    touch = figure_link?(figure) ? 'long' : 'true'
    data = figure.tooltip? ? { controller: 'tooltip', tooltip_touch_value: touch, tooltip_placement_value: placement }.compact : {}
    link_class = class_names('group cursor-pointer', link_class)
    tag_name, attributes =
      if figure.href
        [:a, { **options, href: figure.href, class: [*options[:class], link_class], data: }]
      else
        chart_wrapper(figure_chart(figure), link_class:, data:, **options)
      end
    content_tag(tag_name, **attributes, &)
  end

  def figure_link?(figure) = figure.href.present? || figure_chart(figure).present?

  # The class of the content of a figure that a press on its link scales,
  # like the text and the icon on a segment, so the area of the figure keeps
  # its shape
  def press_class(figure) = ('click-animation' if figure_link?(figure))

  def figure_chart(figure) = figure.sensor_name && chart_sensor_name(figure.sensor_name)

  def tooltip(figure)
    Car::Tooltip::Component.new(title: figure.title, icon: figure.icon, lines: [figure.description].compact, parts: figure.parts, notes: figure.notes, bar: figure.bar)
  end
end
