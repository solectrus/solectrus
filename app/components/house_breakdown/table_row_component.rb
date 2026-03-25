class HouseBreakdown::TableRowComponent < ViewComponent::Base
  def initialize(sensor:, percent:, data:, timeframe:, pinned: false, scaling: :auto)
    super()
    @sensor = sensor
    @percent = percent
    @data = data
    @timeframe = timeframe
    @pinned = pinned
    @scaling = scaling
  end

  attr_reader :sensor, :percent, :data, :timeframe, :pinned, :scaling

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
        'relative flex items-center max-h-10 cursor-pointer transition-colors px-2',
        'border-t border-slate-200 dark:border-black first:border-t-0',
        ('mt-auto' if pinned),
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
        href: helpers.house_home_path(sensor_name: sensor.name, timeframe:),
        stats_with_chart__component_sensor_name_param: sensor.name,
        stats_with_chart__component_chart_url_param: helpers.house_charts_path(sensor_name: sensor.name, timeframe:),
      },
    }
  end

  def bar_background
    tag.div class: 'absolute inset-x-0 inset-y-1 bg-(--table-bar-color) rounded-r-sm transition-[width] motion-safe:duration-1000 motion-reduce:duration-100',
            style: "width: max(1px, #{percent.round}%)"
  end

  def name_column
    tag.span sensor.display_name,
             class: 'relative flex-1 text-slate-700 dark:text-slate-300 truncate'
  end

  def value_column
    tag.span class: 'relative text-right tabular-nums text-slate-700 dark:text-slate-300 ml-1 md:ml-2 min-w-16 md:min-w-24' do
      render SensorValue::Component.new(data, sensor.name, context: timeframe.now? ? :rate : :total, scaling:)
    end
  end

  def percent_column
    tag.span "#{percent.round} %",
             class: 'relative text-right tabular-nums text-slate-500 dark:text-slate-400 ml-1 md:ml-4 whitespace-nowrap w-10 md:w-12'
  end

  def tooltip_content
    tag.div class: 'hidden', data: { tooltip_target: 'html' } do
      render HouseBreakdown::TooltipComponent.new(sensor:, data:, timeframe:)
    end
  end
end
