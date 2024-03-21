class UpdateCheck
  include Singleton

  def latest_version
    latest['version']
  end

  # One of: unregistered, pending, complete, skipped, unknown
  def registration_status
    latest['registration_status'].to_s.inquiry
  end

  def latest
    return {} if Rails.env.development?
    return cached_latest if cached?

    uri = URI(URL)
    response =
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 3,
        read_timeout: 5,
      ) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request.initialize_http_header(
          'Accept' => 'application/json',
          'User-Agent' => UserAgent.instance.to_s,
        )

        http.request(request)
      end

    json_from(response)
  rescue StandardError => e
    # Mainly ignore timeout errors, but other errors must not throw an exception
    Rails.logger.error "UpdateCheck failed: #{e}"
    unknown
  end

  def cached?
    Rails.cache.exist?(cache_key)
  end

  def clear_cache
    Rails.cache.delete(cache_key)
  end

  def skip_registration
    data = latest.merge('registration_status' => 'skipped')

    Rails.cache.write(cache_key, data, expires_in: 24.hours)
  end

  private

  URL = 'https://update.solectrus.de'.freeze
  public_constant :URL

  def cached_latest
    Rails.cache.read(cache_key)
  end

  def json_from(response)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "UpdateCheck failed: Error #{response.code} - #{response.message}"
      return unknown
    end

    parsed_body = JSON.parse(response.body)
    expires_in = expiration_from(response) || 12.hours
    Rails.cache.write(cache_key, parsed_body, expires_in:)
    parsed_body
  end

  def unknown
    data = { 'registration_status' => 'unknown', 'version' => 'unknown' }
    Rails.cache.write(cache_key, data, expires_in: 5.minutes)
    data
  end

  def expiration_from(response)
    response['Cache-Control'].match(/max-age=(\d+)/)&.captures&.first&.to_i
  end

  def cache_key
    ['UpdateCheck', Rails.configuration.x.git.commit_version]
  end
end
