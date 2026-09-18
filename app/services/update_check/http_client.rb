class UpdateCheck::HttpClient
  # Returns either:
  #   { status: :ok, data: {...} }
  # or:
  #   { status: :error, error_message: "..." }
  #
  # The caller (UpdateCheck) decides how to react to errors
  # (e.g. fall back to stale cache, choose log level).
  #
  # How long the answer counts is not decided here. The update server names
  # that moment inside the answer and signs it with the rest, so the caller
  # reads it there (see UpdateCheck::BindingVerifier). A header beside the
  # answer carries no signature and decides nothing.
  def fetch_update_data
    response = fetch_http_response
    unless response.is_a?(Net::HTTPSuccess)
      return error("Error #{response.code} - #{response.message}")
    end

    { status: :ok, data: parse_json(response) }
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    error("timeout: #{e}")
  rescue OpenSSL::SSL::SSLError => e
    error("SSL error: #{e}")
  rescue StandardError => e
    error(e.to_s)
  end

  private

  def error(message)
    { status: :error, error_message: message }
  end

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
      # simplecov:disable
      'https://update.solectrus.localhost'
      # simplecov:enable
    else
      'https://update.solectrus.de'
    end
  end

  # The certificate of the update server is checked in production. Only
  # development and test talk to a local server of their own.
  def verify_mode
    if Rails.env.local?
      OpenSSL::SSL::VERIFY_NONE
    else
      # simplecov:disable
      OpenSSL::SSL::VERIFY_PEER
      # simplecov:enable
    end
  end

  def parse_json(response)
    result = JSON.parse(response.body, symbolize_names: true)
    raise StandardError, 'Invalid response' unless valid_json?(result)

    verify_signature!(result)
    verify_binding!(result)
    result
  end

  def verify_signature!(json)
    UpdateCheck::SignatureVerifier.new(json).verify!
  rescue UpdateCheck::SignatureVerifier::InvalidSignatureError => e
    raise StandardError, "Signature verification failed: #{e.message}"
  end

  # An answer of the update server names the installation it was written for
  # and the moment it stops being fresh. A reply that carries neither is no
  # answer to this request, and one whose moment has passed is an answer played
  # back (see UpdateCheck::BindingVerifier).
  def verify_binding!(json)
    UpdateCheck::BindingVerifier.new(json).verify!
  rescue UpdateCheck::BindingVerifier::InvalidBindingError => e
    raise StandardError, "Binding verification failed: #{e.message}"
  end

  def valid_json?(response)
    response.is_a?(Hash) && response.key?(:version) &&
      response.key?(:registration_status)
  end
end
