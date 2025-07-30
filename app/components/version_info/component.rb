class VersionInfo::Component < ViewComponent::Base
  def initialize(current_version:, commit_time:, github_url:)
    super()
    @current_version = current_version
    @commit_time = commit_time
    @github_url = github_url
  end

  attr_reader :current_version, :commit_time, :github_url

  def outdated?
    version_valid? && comparable(latest_version) > comparable(current_version)
  end

  def version_valid?
    valid?(latest_version) && valid?(current_version)
  end

  def latest_release_url
    if latest_version
      "#{Rails.configuration.x.git.home}/releases/tag/#{latest_version}"
    else
      "#{Rails.configuration.x.git.home}/releases"
    end
  end

  def latest_version
    @latest_version ||= UpdateCheck.latest_version
  end

  private

  def valid?(version)
    version&.start_with?('v')
  end

  def comparable(version)
    Gem::Version.new(version.split('-').first.delete_prefix('v'))
  end
end
