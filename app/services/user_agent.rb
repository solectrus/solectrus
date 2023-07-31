class UserAgent
  include Singleton

  def to_s
    "#{app_name}/#{version} (#{sysname}; #{machine}; #{kernel_release}; #{setup_id})"
  end

  def setup_id
    @setup_id ||= fetch_setup_id
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

  def fetch_setup_id
    return unless (record = Price.first)

    record.created_at.to_i
  end
end
