# A row of the driving card on the car page: the label on the left, the value
# from the block on the right, and an optional bar below them (see
# Car::Card::Component::ROW). The label and the value load the chart of the
# given sensor on click. Without a sensor, they have no chart and show the
# value and its tooltip only.
class Car::StatRow::Component < ViewComponent::Base
  include Car::ChartLink

  FOCUS_RING_CLASSES =
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'.freeze
  private_constant :FOCUS_RING_CLASSES

  # The tooltip opens above, or below without room, because the row has
  # the width of the card. `bar` is the value in the span of its periods
  # (see Car::SpanBar::Component), `css_class` adds to the classes of the
  # row.
  def initialize(title:, sensor_name:, timeframe:, tooltip: nil, bar: nil, css_class: nil)
    super()
    @title = title
    @sensor_name = sensor_name
    @timeframe = timeframe
    @tooltip = tooltip
    @bar = bar
    @css_class = css_class
  end

  attr_reader :title, :sensor_name, :timeframe, :tooltip, :bar

  def linked?
    sensor_name.present?
  end

  def wrapper = chart_wrapper(sensor_name.presence, class: link_classes, data: tooltip_data)

  def row_classes = class_names(Car::Card::Component::ROW, @css_class)

  def label_classes = 'truncate text-sm md:text-base text-slate-500 dark:text-slate-400'

  def value_classes = Car::Card::Component::ROW_VALUE

  private

  # Side by side in a row, one above the other in a tile of a phone
  def link_classes
    class_names(
      'flex max-sm:flex-col max-sm:items-center sm:items-baseline sm:justify-between sm:gap-3 rounded-sm',
      "click-animation #{FOCUS_RING_CLASSES}" => linked?,
    )
  end

  # A tap on a linked row opens the chart, so its tooltip needs a long press.
  # A row without a chart opens its tooltip with a tap.
  def tooltip_data
    return {} unless tooltip

    {
      controller: 'tooltip',
      tooltip_placement_value: 'top',
      tooltip_force_tap_to_close_value: false,
      tooltip_touch_value: linked? ? 'long' : 'true',
    }
  end
end
