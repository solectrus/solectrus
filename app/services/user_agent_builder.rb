class UserAgentBuilder
  include Singleton

  def to_s
    parts = [
      "#{app_name}/#{version}",
      "(#{sysname}; #{machine}; #{kernel_release}; #{setup_id})",
      features_token,
      helios_token,
      influxdb_token,
      postgresql_token,
      redis_token,
    ]
    parts.compact.join(' ')
  end

  private

  def features_token
    "FEATURES/#{UpdateCheck.profile_code}"
  end

  def helios_token
    token_for('HELIOS', HeliosCheck.version(cached: false))
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

  # In production the name carries the digest of the files, in development and
  # test there is none to carry (see AppDigest.current).
  def app_name
    ['SOLECTRUS', AppDigest.current].compact.join('-')
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
