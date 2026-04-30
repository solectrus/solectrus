class UserAgentBuilder
  include Singleton

  def to_s
    parts = [
      "#{app_name}/#{version}",
      "(#{sysname}; #{machine}; #{kernel_release}; #{setup_id})",
      helios_token,
    ]
    parts.compact.join(' ')
  end

  private

  def helios_token
    helios_version = HeliosCheck.version
    "HELIOS/#{helios_version}" if helios_version
  end

  def app_name
    Rails.configuration.x.app_name
  end

  def version
    Rails.configuration.x.git.commit_version
  end

  def sysname
    Etc.uname[:sysname]
  end

  def kernel_release
    Etc.uname[:release]
  end

  def machine
    Etc.uname[:machine]
  end

  def setup_id
    Setting.setup_id
  end
end
