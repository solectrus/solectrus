# @label VersionInfo
class VersionInfoComponentPreview < ViewComponent::Preview
  # @!group Misc

  # @label up-to-date
  def up_to_date
    render VersionInfo::Component.new(
             current_version: 'v1.0.1',
             commit_time: Time.parse('2022-11-06T15:13:16+01:00'),
             github_url: 'https://github.com/solectrus/solectrus',
           )
  end

  # @label outdated
  def outdated
    render VersionInfo::Component.new(
             current_version: 'v0.5.4',
             commit_time: Time.parse('2022-02-13T11:28:16+01:00'),
             github_url: 'https://github.com/solectrus/solectrus',
           )
  end

  # @!endgroup
end
