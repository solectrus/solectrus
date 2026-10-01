# @label RectBadge
# @logical_path data_display
# @display max_width 10rem
class RectBadgeComponentPreview < ViewComponent::Preview
  # @!group Overview

  # @param title
  def default(title: 'Heat pump')
    badge(title:)
  end

  # The title is cut off with an ellipsis when it does not fit.
  def long_title
    badge(title: 'A title that is much too long for the badge')
  end

  # @!endgroup

  private

  # The value renders in a template: a block in the preview class runs in the
  # preview, not in the view, so a component rendered there would be lost.
  def badge(title:)
    render_with_template(
      template: 'rect_badge_component_preview/badge',
      locals: {
        title:,
        data:
          Sensor::Data::Single.new(
            { heatpump_power: 1234.0 },
            timeframe: Timeframe.now,
          ),
      },
    )
  end
end
