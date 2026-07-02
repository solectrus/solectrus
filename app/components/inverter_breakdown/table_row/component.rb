class InverterBreakdown::TableRow::Component < ViewComponent::Base
  def initialize(sensor:, percent:, data:, timeframe:, scaling: :auto)
    super()
    @sensor = sensor
    @percent = percent
    @data = data
    @timeframe = timeframe
    @scaling = scaling
  end

  attr_reader :sensor, :percent, :data, :timeframe, :scaling

  def call
    tag.div(**row_attributes) do
      safe_join(
        [
          bar_background,
          name_column,
          value_column,
          percent_column,
          tooltip_content,
        ],
      )
    end
  end

  private

  def row_attributes
    {
      class: [
        # flex-1 lets rows grow to fill the available height, while min-h-10
        # keeps a floor so many rows overflow into a scroll instead of shrinking.
        'relative flex items-center min-h-10 cursor-pointer transition-colors px-2',
        'border-t border-slate-200 dark:border-black first:border-t-0',
        'flex-1',
      ],
      id: "table-row-#{sensor.name}",
      title: sensor.display_name,
      data: {
        controller: 'tooltip',
        tooltip_placement_value: 'right',
        tooltip_mobile_placement_value: 'bottom',
        tooltip_force_tap_to_close_value: false,
        tooltip_touch_value: 'long',
        action: 'click->stats-with-chart--component#loadChart',
        href: chart_link,
        stats_with_chart__component_sensor_name_param: sensor.name,
        stats_with_chart__component_chart_url_param: helpers.inverter_charts_path(sensor_name: sensor.name, timeframe:),
      },
    }
  end

  # The remainder ("unassigned") sensor has no dedicated detail page.
  def chart_link
    return if sensor.name == :inverter_power_difference

    helpers.inverter_home_path(sensor_name: sensor.name, timeframe:)
  end

  def bar_background
    # A translucent tint of the sensor's own color, so the bar echoes the
    # segment view for the same string while staying light enough for dark text
    # on top (opacity comes from --table-bar-opacity, stronger in dark mode).
    tag.div class: 'absolute inset-x-0 inset-y-1 rounded-r-sm transition-[width] motion-safe:duration-1000 motion-reduce:duration-100',
            style: "background-color: color-mix(in srgb, var(#{bar_color_variable}) var(--table-bar-opacity), transparent); width: max(1px, #{percent.round}%)"
  end

  # Derive the CSS color variable from the sensor's Tailwind class
  # (e.g. "bg-sensor-inverter-1" -> "--color-sensor-inverter-1").
  def bar_color_variable
    "--color-#{sensor.color_background.delete_prefix('bg-')}"
  end

  def name_column
    tag.span sensor.display_name,
             class: 'relative flex-1 w-0 pl-1 md:pl-2 font-light text-slate-700 dark:text-slate-300 truncate'
  end

  def value_column
    tag.span class: 'relative shrink-0 text-right tabular-nums font-light [&_strong]:font-normal text-slate-700 dark:text-slate-300 ml-1 md:ml-2 min-w-16 md:min-w-24' do
      render SensorValue::Component.new(data, sensor.name, context: timeframe.now? ? :rate : :total, scaling:)
    end
  end

  def percent_column
    tag.span "#{percent.round} %",
             class: 'relative shrink-0 text-right tabular-nums text-slate-500 dark:text-slate-400 ml-1 md:ml-4 whitespace-nowrap w-14 md:w-20'
  end

  def tooltip_content
    tag.div class: 'hidden', data: { tooltip_target: 'html' } do
      render InverterBreakdown::Tooltip::Component.new(sensor:, data:, timeframe:)
    end
  end
end
