class UpdateCheck # rubocop:disable Metrics/ClassLength
  include Singleton

  def initialize
    @mutex = Mutex.new
    clear_local_cache!
  end

  class << self
    delegate :sponsoring?,
             :eligible_for_free?,
             :prompt?,
             :simple_prompt?,
             :unregistered?,
             :skipped_prompt?,
             :skip_prompt!,
             :latest_version,
             :registration_status,
             :clear_cache!,
             to: :instance
  end

  def latest_version
    latest[:version]
  end

  # One of: unregistered, pending, complete, unknown
  def registration_status
    latest[:registration_status]
  end

  def subscription_plan
    latest[:subscription_plan]
  end

  def sponsoring?
    subscription_plan.present?
  end

  def eligible_for_free?
    registration_status == 'complete' && !prompt? && !sponsoring?
  end

  def prompt?
    registration_status == 'complete' && latest[:prompt].present?
  end

  def simple_prompt?
    !sponsoring? && !eligible_for_free?
  end

  def unregistered?
    registration_status.in?(%w[unregistered pending])
  end

  def skipped_prompt?
    latest[:prompt] == 'skipped'
  end

  def latest
    return { registration_status: 'complete' } if Rails.env.development?

    local_cache ||
      @mutex.synchronize { local_cache || redis_cache || fetch_remote_data }
  end

  def cached?
    (local_cache || redis_cache).present?
  end

  def clear_cache!
    Rails.cache.delete(cache_key)
    clear_local_cache!
  end

  def skip_prompt!
    data = latest.merge(prompt: 'skipped')

    update_cache(data, expires_in: 24.hours)
  end

  private

  def local_cache
    @local_cache if Time.current < @local_cache_expires_at
  end

  def update_cache(data, expires_in:)
    update_local_cache(data)
    update_redis_cache(data, expires_in: expires_in)
  end

  def update_local_cache(data)
    @local_cache = data
    @local_cache_expires_at = 5.minutes.from_now
  end

  def clear_local_cache!
    @local_cache = nil
    @local_cache_expires_at = Time.current
  end

  def update_redis_cache(data, expires_in:)
    Rails.cache.write(cache_key, data, expires_in:)
  end

  def fetch_remote_data
    response = fetch_http_response
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "UpdateCheck failed: Error #{response.code} - #{response.message}"
      return cached_unknown
    end

    json = json_from(response)
    update_cache(json, expires_in: expiration_from(response) || 12.hours)
    json
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "UpdateCheck failed with timeout: #{e}"
    cached_unknown
  rescue OpenSSL::SSL::SSLError => e
    Rails.logger.error "UpdateCheck failed with SSL error: #{e}"
    cached_unknown
  rescue StandardError => e
    Rails.logger.error "UpdateCheck failed: #{e}"
    cached_unknown
  end

  def cached_unknown
    json = { registration_status: 'unknown' }
    update_cache(json, expires_in: 5.minutes)
    json
  end

  def fetch_http_response
    uri = URI(update_url)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      verify_mode:,
      open_timeout: 10,
      read_timeout: 5,
    ) do |http|
      request = Net::HTTP::Get.new(uri.request_uri)
      request.initialize_http_header(
        'Accept' => 'application/json',
        'User-Agent' => UserAgentBuilder.instance.to_s,
      )

      http.request(request)
    end
  end

  def update_url
    if Rails.env.development?
      # :nocov:
      'https://update.solectrus.test'
      # :nocov:
    else
      'https://update.solectrus.de'
    end
  end

  def verify_mode
    if Rails.env.production?
      # :nocov:
      OpenSSL::SSL::VERIFY_PEER
      # :nocov:
    else
      OpenSSL::SSL::VERIFY_NONE
    end
  end

  def redis_cache
    result = Rails.cache.read(cache_key)
    update_local_cache(result) if result
    result
  end

  def json_from(response)
    result = JSON.parse(response.body, symbolize_names: true)
    raise StandardError, 'Invalid response' unless valid_json?(result)

    result
  end

  def valid_json?(response)
    response.is_a?(Hash) && response.key?(:version) &&
      response.key?(:registration_status)
  end

  def expiration_from(response)
    cache_control = response['Cache-Control']
    return unless cache_control

    max_age = cache_control[/max-age=(\d+)/, 1]
    max_age&.to_i
  end

  def cache_key
    "UpdateCheck:#{Rails.configuration.x.git.commit_version}"
  end
end
