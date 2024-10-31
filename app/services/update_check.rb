class UpdateCheck
  include Singleton

  %i[
    sponsoring?
    eligible_for_free?
    prompt?
    simple_prompt?
    unregistered?
    skipped_prompt?
    skip_prompt!
    latest_version
    registration_status
    clear_cache!
  ].each do |method|
    define_singleton_method(method) { instance.public_send(method) }
  end

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

  def eligible_for_free?
    registration_status.complete? && !prompt? && !sponsoring?
  end

  def prompt?
    registration_status.complete? && latest[:prompt].present?
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
    @latest ||=
      if Rails.env.development?
        # :nocov:
        { registration_status: 'complete' }
        # :nocov:
      elsif cached?
        cached_latest
      else
        http_request
      end
  end

  def cached?
    Rails.cache.exist?(cache_key)
  end

  def clear_cache!
    Rails.cache.delete(cache_key)
    @latest = nil
  end

  def skip_prompt!
    data = latest.merge(prompt: 'skipped')
    Rails.cache.write(cache_key, data, expires_in: 24.hours)
    @latest = data
  end

  private

  def http_request
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
          'User-Agent' => UserAgentBuilder.instance.to_s,
        )

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
    data = { registration_status: 'unknown' }
    Rails.cache.write(cache_key, data, expires_in: 5.minutes)
    data
  end

  def expiration_from(response)
    max_age = response['Cache-Control'][/max-age=(\d+)/, 1]
    max_age&.to_i
  end

  def cache_key
    ['UpdateCheck', Rails.configuration.x.git.commit_version]
  end
end
