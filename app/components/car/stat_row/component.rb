# A row of a card on the car page: a label on the left, the value from the
# block on the right. It loads the chart of the given sensor on click.
# Without a sensor, the row has no chart and shows its value and its tooltip
# only.
class Car::StatRow::Component < ViewComponent::Base
  include CarChartLink

  FOCUS_RING_CLASSES =
    'focus:outline-none focus-visible:ring-2 focus-visible:ring-gray-700 dark:focus-visible:ring-gray-400'.freeze
  private_constant :FOCUS_RING_CLASSES

  # The rows sit at the bottom of the card, so a tooltip opens above them.
  # A large row takes an equal part of the height, with its label above its
  # value in the center. It fills a card that has nothing else below its
  # headline.
  def initialize(title:, sensor_name:, timeframe:, tooltip: nil, tooltip_placement: 'top', large: false)
    super()
    @title = title
    @sensor_name = sensor_name
    @timeframe = timeframe
    @tooltip = tooltip
    @tooltip_placement = tooltip_placement
    @large = large
  end

  attr_reader :title, :sensor_name, :timeframe, :tooltip, :tooltip_placement

  def linked?
    sensor_name.present?
  end

  def wrapper_tag
    linked? ? :a : :div
  end

  def wrapper_options
    if linked?
      { href: chart_link_url(sensor_name), class: row_classes, data: tooltip_data.merge(chart_link_data(sensor_name)) }
    else
      { class: row_classes, data: tooltip_data }
    end
  end

  def label_classes
    class_names(
      'truncate text-slate-500 dark:text-slate-400',
      @large ? 'text-sm md:text-base' : 'text-xs sm:text-sm',
    )
  end

  def value_classes
    class_names(
      'font-semibold tabular-nums whitespace-nowrap text-slate-700 dark:text-slate-200',
      @large ? 'mt-1 text-2xl md:text-4xl' : 'text-base md:text-xl',
    )
  end

  private

  def row_classes
    class_names(
      'flex flex-col gap-x-3 min-w-0 rounded-md border-t border-slate-200 dark:border-slate-700',
      @large ? 'flex-1 items-center justify-center text-center' : 'pt-2 items-center text-center sm:flex-row sm:items-baseline sm:justify-between sm:text-left',
      "click-animation #{FOCUS_RING_CLASSES}" => linked?,
    )
  end

  # A tap on a linked row opens the chart, so its tooltip needs a long press.
  # A row without a chart opens its tooltip with a tap.
  def tooltip_data
    return {} unless tooltip

    {
      controller: 'tooltip',
      tooltip_placement_value: tooltip_placement,
      tooltip_force_tap_to_close_value: false,
      tooltip_touch_value: linked? ? 'long' : 'true',
    }
  end
end
