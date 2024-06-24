class UpdateCheck
  include Singleton

  def latest_version
    latest[:version]
  end

  # One of: unregistered, pending, complete, unknown
  def registration_status
    latest[:registration_status].to_s.inquiry
  end

  def subscription_plan
    latest[:subscription_plan].to_s.inquiry
  end

  def sponsoring?
    subscription_plan.present?
  end

  def prompt?
    registration_status.complete? && latest[:prompt].present?
  end

  def skipped_prompt?
    latest[:prompt] == 'skipped'
  end

  def latest
    return cached_latest if cached?

    uri = URI(update_url)
    response =
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
          'User-Agent' => UserAgent.instance.to_s,
        )

        http.verify_callback =
          lambda do |preverify_ok, ssl_context|
            if !preverify_ok || ssl_context.error != 0
              Rails.logger.error "UpdateCheck failed during SSL verification: #{ssl_context.error_string}"
              false
            else
              true
            end
          end

        http.request(request)
      end

    json_from(response)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    Rails.logger.error "UpdateCheck failed with timeout: #{e}"
    unknown
  rescue OpenSSL::SSL::SSLError => e
    Rails.logger.error "UpdateCheck failed with SSL error: #{e}"
    unknown
  rescue StandardError => e
    Rails.logger.error "UpdateCheck failed: #{e}"
    unknown
  end

  def cached?
    Rails.cache.exist?(cache_key)
  end

  def clear_cache
    Rails.cache.delete(cache_key)
  end

  def skip_prompt!
    data = latest.merge(prompt: 'skipped')

    Rails.cache.write(cache_key, data, expires_in: 24.hours)
  end

  private

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

  def cached_latest
    Rails.cache.read(cache_key)
  end

  def json_from(response)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "UpdateCheck failed: Error #{response.code} - #{response.message}"
      return unknown
    end

    parsed_body = JSON.parse(response.body, symbolize_names: true)
    expires_in = expiration_from(response) || 12.hours
    Rails.cache.write(cache_key, parsed_body, expires_in:)
    parsed_body
  end

  def unknown
    data = { registration_status: 'unknown', version: 'unknown' }
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
