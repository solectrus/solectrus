# @label Sponsoring teaser
# @logical_path feedback
# @display max_width 100%
class DemoLinkComponentPreview < ViewComponent::Preview
  # In place of a page that needs a sponsorship
  def page
    render DemoLink::Component.new(feature: 'heatpump', url: { controller: 'heatpump/home', timeframe: 'day' })
  end
end
