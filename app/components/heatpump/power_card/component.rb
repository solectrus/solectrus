class Heatpump::PowerCard::Component < ViewComponent::Base
  def initialize(data:, timeframe:, css_class:)
    super()
    @data = data
    @timeframe = timeframe
    @css_class = css_class
  end

  attr_reader :data, :timeframe, :css_class

  def render?
    data.heatpump_power.present?
  end

  def link_url
    helpers.url_for(controller: 'home', sensor_name: 'heatpump_power', timeframe:)
  end

  def link_classes
    class_names(
      css_class,
      'grow min-w-0',
      'bg-slate-200 dark:bg-slate-800 px-3 py-2.5 md:px-4' => !timeframe.now?,
      'rounded-r-none' => !timeframe.now? && data.heatpump_costs,
    )
  end

  def link_data
    attrs = {
      turbo_prefetch: 'false',
      'stats-with-chart--component-target': 'current',
      'sensor-name': 'heatpump_power',
      value: data.heatpump_power,
      time: data.time.to_i,
      action: 'stats-with-chart--component#loadChart',
      stats_with_chart__component_sensor_name_param: 'heatpump_power',
      stats_with_chart__component_chart_url_param:
        helpers.heatpump_charts_path(sensor_name: 'heatpump_power', timeframe:),
    }
    if show_tooltip?
      attrs.merge!(
        controller: 'tooltip',
        tooltip_placement_value: 'bottom',
        tooltip_force_tap_to_close_value: false,
        tooltip_touch_value: 'long',
      )
    end
    attrs
  end

  def show_ratio_bar?
    !timeframe.now? && grid_ratio
  end

  alias show_tooltip? show_ratio_bar?

  def power_pv_ratio
    100 - grid_ratio
  end

  def grid_ratio
    return @grid_ratio if defined?(@grid_ratio)

    @grid_ratio = data.heatpump_power_grid_ratio
  end

  def tooltip_rows
    [
      { bg: 'bg-sensor-pv', label: I18n.t('splitter.pv'), sensor: :heatpump_power_pv },
      { bg: 'bg-sensor-grid', label: I18n.t('splitter.grid'), sensor: :heatpump_power_grid },
    ]
  end
end
