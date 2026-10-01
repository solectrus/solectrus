# @label InsightsTile
# @logical_path data_display
# @display max_width 24rem
class InsightsTileComponentPreview < ViewComponent::Preview
  # @!group Overview

  def default
    tile
  end

  def stripes
    tile(options: { stripes: true })
  end

  def with_extra_class
    tile(options: { css_class: 'font-mono' })
  end

  def with_link
    tile(options: { url: '/#' })
  end

  def without_footer
    tile(footer: nil)
  end

  def without_title
    tile(title: nil)
  end

  def body_only
    tile(title: nil, body: 'This is the body', footer: nil)
  end

  # @!endgroup

  private

  # The slots render in a template: a block in the preview class runs in the
  # preview, not in the view, so a component rendered there would be lost.
  def tile(
    options: {},
    title: 'Title here',
    body: nil,
    footer: 'Footer content here.'
  )
    render_with_template(
      template: 'insights_tile_component_preview/tile',
      locals: {
        options:,
        title:,
        body:,
        footer:,
      },
    )
  end
end
