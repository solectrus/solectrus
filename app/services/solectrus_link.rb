# Every outbound link to solectrus.de and to the demo installation.
#
# Both sites count their traffic with Plausible, and Plausible reads these
# parameters. Without them a visit from inside the app cannot be told from any
# other visit, and no placement in the app can be judged.
#
# One source for the whole app, so the reports do not split into a bucket per
# link. `campaign` names the place the link sits in. `content` narrows it down
# where one place has more than one link.
#
# Notification::Show::Component tags its links on its own. It rewrites the
# hrefs of free HTML, which is a different job than building a known URL.
class SolectrusLink
  SOURCE = 'solectrus-app'.freeze
  MEDIUM = 'referral'.freeze
  public_constant :SOURCE, :MEDIUM

  # For a link that is built from a Rails route, so the parameters can be
  # merged into the hash that `url_for` receives.
  def self.params(campaign:, content: nil)
    {
      utm_source: SOURCE,
      utm_medium: MEDIUM,
      utm_campaign: campaign,
      utm_content: content,
    }.compact
  end

  # For a link that is written out as a plain address.
  def self.url(base, campaign:, content: nil)
    "#{base}?#{params(campaign:, content:).to_query}"
  end
end
