# The head of a tooltip: an optional icon, the title, and the main value. The
# floating tooltip stacks them in its narrow column, the bottom sheet on a
# phone puts the icon beside title and value (tooltip_content.css).
#
# The main value comes from `sensor_name` and `value` (a number or the data to
# read it from): a rate, or a total, which is larger. The block adds more
# below it.
class TooltipHeader::Component < ViewComponent::Base
  renders_one :icon

  def initialize(title:, sensor_name: nil, value: nil, total: false)
    super()
    @title = title
    @sensor_name = sensor_name
    @value = value
    @total = total
  end

  attr_reader :title, :sensor_name

  def main_value
    SensorValue::Component.new(
      @value,
      sensor_name,
      context: @total ? :total : :auto,
      precision: 3,
      class: @total ? 'tooltip-value tooltip-value-lg' : 'tooltip-value',
    )
  end
end
