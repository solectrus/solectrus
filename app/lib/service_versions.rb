module ServiceVersions
  RECOMMENDED_INFLUXDB_VERSION = Gem::Version.new('2.8').freeze
  private_constant :RECOMMENDED_INFLUXDB_VERSION

  def self.fetch_influxdb
    raw = Influx.health.version
    version = Gem::Version.new(raw.delete_prefix('v'))

    if version < RECOMMENDED_INFLUXDB_VERSION
      Rails.logger.warn(
        "InfluxDB version #{version} detected. " \
          "Consider upgrading to #{RECOMMENDED_INFLUXDB_VERSION} for best compatibility and performance.",
      )
    end

    version
  rescue StandardError => e
    Rails.logger.error("Error determining InfluxDB version: #{e.message}")
    nil
  end

  def self.fetch_postgresql
    raw = ApplicationRecord.connection.select_value('SHOW server_version')&.split&.first
    Gem::Version.new(raw) if raw
  rescue StandardError
    nil
  end

  def self.fetch_redis
    return unless Rails.cache.respond_to?(:redis)

    raw = Rails.cache.redis.with { |r| r.info('server')['redis_version'] }
    Gem::Version.new(raw) if raw.present?
  rescue StandardError
    nil
  end

  # Eagerly determined at module load (single-threaded by Zeitwerk), so the
  # `attr_reader` accessors below are thread-safe afterwards.
  @influxdb = fetch_influxdb
  @postgresql = fetch_postgresql
  @redis = fetch_redis

  class << self
    attr_reader :influxdb, :postgresql, :redis
  end

  def self.at_least?(service, version_string)
    current = public_send(service)
    return false unless current

    current >= Gem::Version.new(version_string)
  end
end
