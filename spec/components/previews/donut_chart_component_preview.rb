# @label DonutChart
# @logical_path data_visualization
# @display max_width 20rem
class DonutChartComponentPreview < ViewComponent::Preview
  # @!group Overview

  def three_segments
    donut_chart(segments: [env, pv(35), grid(25)], center: 'Center')
  end

  def two_segments
    donut_chart(segments: [pv(70), grid(30)])
  end

  # Without segments, a gray ring stands in for the chart.
  def placeholder
    donut_chart(segments: nil, center: 'No data')
  end

  # @!endgroup

  private

  # The chart sizes itself by container queries, so it needs a parent of a
  # fixed height, as on the heat pump page.
  def donut_chart(segments:, center: nil)
    render_with_template(
      template: 'donut_chart_component_preview/frame',
      locals: {
        segments:,
        center:,
      },
    )
  end

  def env
    segment(:heatpump_power_env, 40, '--color-sensor-heatpump-env')
  end

  def pv(percent)
    segment(:heatpump_power_pv, percent, '--color-sensor-pv')
  end

  def grid(percent)
    segment(:heatpump_power_grid, percent, '--color-sensor-grid')
  end

  def segment(sensor_name, percent, color_var)
    {
      percent:,
      color_var:,
      label: Sensor::Registry[sensor_name].display_name,
      sensor_name: sensor_name.to_s,
    }
  end
end
