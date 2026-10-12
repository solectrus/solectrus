# @label VersionInfo
# @logical_path feedback
class VersionInfoComponentPreview < ViewComponent::Preview
  # @!group Overview

  # @label up-to-date
  def up_to_date
    render VersionInfo::Component.new(
             current_version: 'v1.3.4',
             commit_time: Time.parse('2026-10-12T11:34:27+02:00'),
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
