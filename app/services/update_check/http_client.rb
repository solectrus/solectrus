class UpdateCheck::HttpClient
  def fetch_update_data
    response = fetch_http_response
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "UpdateCheck failed: Error #{response.code} - #{response.message}"
      return { data: { registration_status: 'unknown' }, expires_in: 5.minutes }
    end

    json = parse_json(response)
    expires_in = expiration_from(response) || 12.hours
    Rails.logger.info "Checked for update availability, valid for #{expires_in / 60} minutes"

    { data: json, expires_in: }
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "UpdateCheck failed with timeout: #{e}"
    { data: { registration_status: 'unknown' }, expires_in: 5.minutes }
  rescue OpenSSL::SSL::SSLError => e
    Rails.logger.error "UpdateCheck failed with SSL error: #{e}"
    { data: { registration_status: 'unknown' }, expires_in: 5.minutes }
  rescue StandardError => e
    Rails.logger.error "UpdateCheck failed: #{e}"
    { data: { registration_status: 'unknown' }, expires_in: 5.minutes }
  end

  private

  def fetch_http_response
    uri = URI(update_url)
    Net::HTTP.start(
      uri.host,
      uri.port,
      use_ssl: true,
      verify_mode: verify_mode,
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

  def parse_json(response)
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
end
