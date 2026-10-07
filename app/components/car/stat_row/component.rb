# A row of the driving card on the car page: the label above the value from
# the block, and an optional line below it (see Car::Card::Component::ROW).
# Two rows stand side by side. The row loads the chart of the given sensor on
# click. Without a sensor, the row has no chart and shows its value and its
# tooltip only.
class Car::StatRow::Component < ViewComponent::Base
  include CarChartLink

  # A line below the value, for example the unit of a rate
  renders_one :subline

  FOCUS_RING_CLASSES =
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'.freeze
  private_constant :FOCUS_RING_CLASSES

  # The tooltip opens to the left, like the usage column of the power
  # balance. `css_class` adds to the classes of the row.
  def initialize(title:, sensor_name:, timeframe:, tooltip: nil, css_class: nil)
    super()
    @title = title
    @sensor_name = sensor_name
    @timeframe = timeframe
    @tooltip = tooltip
    @css_class = css_class
  end

  attr_reader :title, :sensor_name, :timeframe, :tooltip

  def linked?
    sensor_name.present?
  end

  def wrapper = chart_wrapper(sensor_name.presence, class: row_classes, data: tooltip_data)

  def label_classes = 'truncate text-sm text-slate-500 dark:text-slate-400'

  def value_classes = "mt-1 #{Car::Card::Component::ROW_VALUE}"

  def subline_classes = Car::Card::Component::ROW_CAPTION

  private

  def row_classes
    class_names(
      Car::Card::Component::ROW,
      "click-animation #{FOCUS_RING_CLASSES}" => linked?,
      @css_class => @css_class.present?,
    )
  end

  # A tap on a linked row opens the chart, so its tooltip needs a long press.
  # A row without a chart opens its tooltip with a tap.
  def tooltip_data
    return {} unless tooltip

    {
      controller: 'tooltip',
      tooltip_placement_value: 'left',
      tooltip_force_tap_to_close_value: false,
      tooltip_touch_value: linked? ? 'long' : 'true',
    }
  end
end
