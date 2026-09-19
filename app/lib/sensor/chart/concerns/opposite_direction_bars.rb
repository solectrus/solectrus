module Sensor
  module Chart
    module Concerns
      # Shared styling for charts whose two series grow in opposite directions by
      # negating one of them (e.g. battery charge/discharge, grid export/import).
      # The negated series carries its direction in the bar direction and label,
      # so the tooltip should show the magnitude without the redundant minus sign
      # (tooltipAbs) and the y-axis should render magnitudes in both directions
      # (formatAbs) instead of a negative scale.
      #
      # An including chart names the pair in #opposite_sensor_names, the upward
      # sensor first and the negated one second.
      module OppositeDirectionBars
        extend ActiveSupport::Concern

        # Bars grow in opposite directions (not stacked), so gradient looks good.
        def style_for_sensor(sensor)
          super.merge(noGradient: false, tooltipAbs: true)
        end

        def options
          super.deep_merge(scales: { y: { ticks: { callback: 'formatAbs' } } })
        end

        private

        def chart_sensor_names
          opposite_sensor_names
        end
      end
    end
  end
end
