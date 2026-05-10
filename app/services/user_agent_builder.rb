class UserAgentBuilder
  include Singleton

  def to_s
    parts = [
      "#{app_name}/#{version}",
      "(#{sysname}; #{machine}; #{kernel_release}; #{setup_id})",
      helios_token,
      influxdb_token,
      postgresql_token,
      redis_token,
    ]
    parts.compact.join(' ')
  end

  private

  def helios_token
    token_for('HELIOS', HeliosCheck.version)
  end

  def influxdb_token
    token_for('INFLUXDB', ServiceVersions.influxdb)
  end

  def postgresql_token
    token_for('POSTGRESQL', ServiceVersions.postgresql)
  end

  def redis_token
    token_for('REDIS', ServiceVersions.redis)
  end

  def token_for(name, version)
    "#{name}/#{version}" if version.present?
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
