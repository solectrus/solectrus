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
  ACTION_REQUIRED_HEADER = 'X-Action-Required'.freeze
  CACHE_KEY = 'HeliosCheck:version'.freeze
  CACHE_DURATION = 24.hours
  ACTION_REQUIRED_CACHE_KEY = 'HeliosCheck:action_required'.freeze
  ACTION_REQUIRED_CACHE_DURATION = 30.seconds
  NO_ACTION_CACHE_DURATION = 1.hour
  CACHE_RACE_TTL = 30
  PROBE_TIMEOUT = 1
  private_constant :HOSTNAME,
                   :PROBE_PORT,
                   :BROWSER_PORT,
                   :HEALTH_PATH,
                   :VERSION_HEADER,
                   :ACTION_REQUIRED_HEADER,
                   :CACHE_KEY,
                   :CACHE_DURATION,
                   :ACTION_REQUIRED_CACHE_KEY,
                   :ACTION_REQUIRED_CACHE_DURATION,
                   :NO_ACTION_CACHE_DURATION,
                   :CACHE_RACE_TTL,
                   :PROBE_TIMEOUT

  class << self
    delegate :available?,
             :version,
             :action_required?,
             :browser_url,
             :clear_cache!,
             to: :instance
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
      ) { probe(VERSION_HEADER).presence || false }
      .presence
  end

  # HELIOS asks the user to come over: its configuration is incomplete, or its
  # stack waits for a restart or fails. The two answers keep for different
  # times. A new request of HELIOS can reach the user an hour late. A request
  # the user has done in HELIOS must leave the page soon, or it confuses them.
  def action_required?
    return false unless available?

    Rails.cache.fetch(
      ACTION_REQUIRED_CACHE_KEY,
      race_condition_ttl: CACHE_RACE_TTL,
    ) do |_key, options|
      required = probe(ACTION_REQUIRED_HEADER) == '1'
      options.expires_in =
        required ? ACTION_REQUIRED_CACHE_DURATION : NO_ACTION_CACHE_DURATION
      required
    end
  end

  def browser_url(request)
    "#{request.protocol}#{request.host}:#{BROWSER_PORT}"
  end

  def clear_cache!
    Rails.cache.delete(CACHE_KEY)
    Rails.cache.delete(ACTION_REQUIRED_CACHE_KEY)
  end

  private

  def probe(header)
    response =
      Net::HTTP.start(
        HOSTNAME,
        PROBE_PORT,
        open_timeout: PROBE_TIMEOUT,
        read_timeout: PROBE_TIMEOUT,
      ) { |http| http.get(HEALTH_PATH) }

    response[header] if response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.debug { "HeliosCheck: not available: #{e.class}: #{e.message}" }
    nil
  end
end
