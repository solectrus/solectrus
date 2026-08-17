class DemoLink::Component < ViewComponent::Base
  DEMO_HOST = 'https://demo.solectrus.de'.freeze
  CAMPAIGN = 'feature-teaser'.freeze
  private_constant :DEMO_HOST, :CAMPAIGN

  def initialize(feature:, url: nil)
    super()
    @url = url
    @feature = feature
  end

  attr_reader :url, :feature

  # The caller passes the route of the page it stands on, so the demo opens the
  # same page. Only the host and the tracking are added here.
  #
  # This is the one outbound link of a teaser, so it is also the only one that
  # needs the parameters. `utm_content` names the feature, which answers which
  # teaser earns its place.
  def demo_url
    return unless url

    {
      **url,
      **SolectrusLink.params(campaign: CAMPAIGN, content: feature),
      host: DEMO_HOST,
      port: 443,
      protocol: 'https',
    }
  end
end
