# @label Sponsoring teaser
# @logical_path feedback
# @display max_width 100%
class DemoLinkComponentPreview < ViewComponent::Preview
  # In place of a page that needs a sponsorship
  def page
    render DemoLink::Component.new(feature: 'heatpump', url: { controller: 'heatpump/home', timeframe: 'day' })
  end

  # In the sheet of the trends, on its gray, at the width of a phone
  # @display max_width 390px
  def sheet
    component = DemoLink::Component.new(feature: 'trends', url: { controller: 'balance/home', sensor_name: 'inverter_power', timeframe: 'year' })
    render_with_template(template: 'demo_link_component_preview/sheet', locals: { component: })
  end
end
