require 'net/http'

# The address at a location, from Nominatim, the geocoder of OpenStreetMap.
# A Place asks once and keeps the answer (see Place#geocode!), so this client
# has no cache of its own. Nominatim allows one request per second, so two
# requests of the process keep this distance. After a failure, the process
# asks nothing for a while (see PAUSE).
#
# NOMINATIM_URL selects another server of Nominatim, for example one of your
# own. An empty NOMINATIM_URL turns it off, so SOLECTRUS sends no location.
# The request sends the location and a User-Agent with the name and the
# version of the app and nothing more, because Nominatim is not a service of
# SOLECTRUS.
module Place::Nominatim
  # The zoom of Nominatim that gives a building with its address
  ZOOM = 18
  private_constant :ZOOM

  TIMEOUT = 2.seconds
  private_constant :TIMEOUT

  INTERVAL = 1.second
  private_constant :INTERVAL

  # A server that refuses (for example with 429) gets no request with each
  # refresh of the live view
  PAUSE = 5.minutes
  private_constant :PAUSE

  # The time of the last request, which the mutex guards
  MUTEX = Mutex.new
  private_constant :MUTEX

  LAST_REQUEST = Concurrent::AtomicReference.new(-INTERVAL)
  private_constant :LAST_REQUEST

  PAUSED_UNTIL = Concurrent::AtomicReference.new(-Float::INFINITY)
  private_constant :PAUSED_UNTIL

  def self.enabled? = Rails.configuration.x.nominatim_url.present?

  # The answer as a Hash, in the current locale, or nil without an answer
  def self.reverse(latitude, longitude)
    response = MUTEX.synchronize { throttled { request(latitude, longitude) } if ready? }
    return unless response
    raise Net::HTTPError.new("HTTP #{response.code}", response) unless response.is_a?(Net::HTTPSuccess)

    answer = JSON.parse(response.body)
    answer if answer.is_a?(Hash) && answer['address']
  rescue StandardError => e
    PAUSED_UNTIL.set(now + PAUSE)
    Rails.logger.warn("Place::Nominatim: #{e.class}: #{e.message}")
    nil
  end

  # Turned on, and no pause after a failure
  def self.ready? = enabled? && now >= PAUSED_UNTIL.get
  private_class_method :ready?

  # Waits for the rest of INTERVAL since the last request
  def self.throttled
    wait = INTERVAL - (now - LAST_REQUEST.get)
    sleep(wait) if wait.positive?
    yield
  ensure
    LAST_REQUEST.set(now)
  end
  private_class_method :throttled

  def self.request(latitude, longitude)
    started = now
    uri = URI("#{Rails.configuration.x.nominatim_url.chomp('/')}/reverse")
    uri.query = URI.encode_www_form(format: 'jsonv2', lat: latitude, lon: longitude, zoom: ZOOM, 'accept-language': I18n.locale)

    response =
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, 'User-Agent' => user_agent, 'Accept' => 'application/json')
      end
    log(uri, latitude, longitude, "HTTP #{response.code}", started)
    response
  rescue StandardError => e
    log(uri, latitude, longitude, e.class, started)
    raise
  end
  private_class_method :request

  # Each request, with its server and its result, so the log shows how often
  # SOLECTRUS asks Nominatim
  def self.log(uri, latitude, longitude, result, started)
    Rails.logger.info(
      format(
        'Place::Nominatim: %<host>s for %<latitude>.4f,%<longitude>.4f: %<result>s in %<ms>d ms',
        host: uri&.host,
        latitude:,
        longitude:,
        result:,
        ms: (now - started) * 1000,
      ),
    )
  end
  private_class_method :log

  # Each installation of SOLECTRUS runs on a host of its user
  def self.user_agent = "SOLECTRUS/#{Rails.configuration.x.git.commit_version} (self-hosted; +https://solectrus.de)"
  private_class_method :user_agent

  def self.now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  private_class_method :now
end
