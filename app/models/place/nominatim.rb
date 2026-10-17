require 'net/http'

# The address at a location, and the location of an address, from Nominatim,
# the geocoder of OpenStreetMap. A Place asks once and keeps the answer (see
# Place#geocode!), so this client has no cache of its own. Nominatim allows
# one request per second, so two requests of the process keep this distance.
# After a failure, the process asks this endpoint nothing for a while (see
# PAUSE).
#
# NOMINATIM_URL selects another server of Nominatim, for example one of your
# own. An empty NOMINATIM_URL turns it off, so SOLECTRUS sends no location.
# The request sends the location or the address and a User-Agent with the
# name and the version of the app and nothing more, because Nominatim is not
# a service of SOLECTRUS.
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

  # Each endpoint pauses on its own, so a failed reverse of the live view
  # does not stop the search of an address, and the other way round
  PAUSED_UNTIL = %w[reverse search].index_with { Concurrent::AtomicReference.new(-Float::INFINITY) }.freeze
  private_constant :PAUSED_UNTIL

  # Nominatim is turned off, or gave no answer
  class Unavailable < StandardError
  end

  def self.enabled? = Rails.configuration.x.nominatim_url.present?

  # The answer as a Hash, in the current locale, or nil without an answer
  def self.reverse(latitude, longitude)
    answer = ask('reverse', lat: latitude, lon: longitude, zoom: ZOOM, 'accept-language': I18n.locale)
    answer if answer.is_a?(Hash) && answer['address']
  end

  # The best match of an address as a Hash with its address, or nil without
  # a match. A country code like "de" limits the search to this country.
  # The names are in the language of the country, as an address shows them,
  # not in the locale of the app.
  # Unlike a missing match, a failure raises Unavailable, because the caller
  # cannot tell whether the address exists.
  def self.search(query, country_code: nil)
    answer = ask('search', q: query, countrycodes: country_code, addressdetails: 1, limit: 1)
    raise Unavailable unless answer.is_a?(Array)

    answer.first
  end

  # The parsed answer of an endpoint, or nil after a failure
  def self.ask(endpoint, **params)
    response = MUTEX.synchronize { throttled { request(endpoint, params) } if ready?(endpoint) }
    return unless response
    raise Net::HTTPError.new("HTTP #{response.code}", response) unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue StandardError => e
    PAUSED_UNTIL[endpoint].set(now + PAUSE)
    Rails.logger.warn("Place::Nominatim: #{e.class}: #{e.message}")
    nil
  end
  private_class_method :ask

  # Turned on, and no pause after a failure
  def self.ready?(endpoint) = enabled? && now >= PAUSED_UNTIL[endpoint].get
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

  def self.request(endpoint, params)
    started = now
    uri = URI("#{Rails.configuration.x.nominatim_url.chomp('/')}/#{endpoint}")
    uri.query = URI.encode_www_form({ format: 'jsonv2', **params }.compact)

    response =
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
        http.get(uri.request_uri, 'User-Agent' => user_agent, 'Accept' => 'application/json')
      end
    log(uri, params, "HTTP #{response.code}", started)
    response
  rescue StandardError => e
    log(uri, params, e.class, started)
    raise
  end
  private_class_method :request

  # Each request, with its server and its result, so the log shows how often
  # SOLECTRUS asks Nominatim. It names no address, which is personal data.
  def self.log(uri, params, result, started)
    subject = params[:lat] ? format('%<lat>.4f,%<lon>.4f', params.slice(:lat, :lon)) : 'an address'
    Rails.logger.info(
      format(
        'Place::Nominatim: %<host>s for %<subject>s: %<result>s in %<ms>d ms',
        host: uri&.host,
        subject:,
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
