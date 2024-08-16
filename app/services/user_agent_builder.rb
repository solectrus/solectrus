class UserAgentBuilder
  include Singleton

  def to_s
    "#{app_name}/#{version} (#{sysname}; #{machine}; #{kernel_release}; #{setup_id})"
  end

  private

  def app_name
    'SOLECTRUS'
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
