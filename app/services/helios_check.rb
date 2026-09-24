require 'net/http'

class HeliosCheck
  include Singleton

  HOSTNAME = 'helios'.freeze
  # Helios listens on 3000 inside its container; the browser reaches it via
  # the host-mapped port 3999 (see compose.yaml: ports: 3999:3000).
  PROBE_PORT = 3000
  BROWSER_PORT = 3999
  HEALTH_PATH = '/up'.freeze
  VERSION_HEADER = 'X-Version'.freeze
  CACHE_KEY = 'HeliosCheck:version'.freeze
  CACHE_DURATION = 24.hours
  CACHE_RACE_TTL = 30
  PROBE_TIMEOUT = 1
  private_constant :HOSTNAME,
                   :PROBE_PORT,
                   :BROWSER_PORT,
                   :HEALTH_PATH,
                   :VERSION_HEADER,
                   :CACHE_KEY,
                   :CACHE_DURATION,
                   :CACHE_RACE_TTL,
                   :PROBE_TIMEOUT

  class << self
    delegate :available?, :version, :browser_url, :clear_cache!, to: :instance
  end

  # In development and test no Helios runs beside the application to probe, in
  # production one can (see UpdateCheck.skip_http?).
  def self.skip_http?
    Rails.env.local?
  end

  def available?
    version.present?
  end

  # `cached: false` asks HELIOS instead of the cache and renews the cache with
  # the answer. For a caller that reports the version (see UserAgentBuilder):
  # the cache can hold the version from before an update of HELIOS. Such a
  # caller runs rarely and beside a request of its own, so the probe costs no
  # page.
  def version(cached: true)
    return if self.class.skip_http?

    Rails
      .cache
      .fetch(
        CACHE_KEY,
        expires_in: CACHE_DURATION,
        race_condition_ttl: CACHE_RACE_TTL,
        force: !cached,
      ) { probe || false }
      .presence
  end

  def browser_url(request)
    "#{request.protocol}#{request.host}:#{BROWSER_PORT}"
  end

  def clear_cache!
    Rails.cache.delete(CACHE_KEY)
  end

  private

  def probe
    response =
      Net::HTTP.start(
        HOSTNAME,
        PROBE_PORT,
        open_timeout: PROBE_TIMEOUT,
        read_timeout: PROBE_TIMEOUT,
      ) { |http| http.get(HEALTH_PATH) }

    return unless response.is_a?(Net::HTTPSuccess)

    response[VERSION_HEADER].presence
  rescue StandardError => e
    Rails.logger.debug { "HeliosCheck: not available: #{e.class}: #{e.message}" }
    nil
  end
end
