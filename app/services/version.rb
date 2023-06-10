class Version
  CHECK_URL = 'https://update.solectrus.de'.freeze
  public_constant :CHECK_URL

  def self.latest
    new.latest
  end

  def latest
    return cached_version if cached?

    uri = URI(CHECK_URL)
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

    version_from(response) if response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    # Mainly ignore timeout errors, but other errors must not throw an exception
    nil
  end

  def cached?
    Rails.cache.exist?(cache_key)
  end

  private

  def version_from(response)
    version = JSON.parse(response.body)['version']
    expires_in = expiration_from(response) || 12.hours
    Rails.cache.write(cache_key, version, expires_in:)
    version
  end

  def cached_version
    Rails.cache.read(cache_key)
  end

  def expiration_from(response)
    response['Cache-Control'].match(/max-age=(\d+)/)&.captures&.first&.to_i
  end

  def cache_key
    ['Version.latest', Rails.configuration.x.git.commit_version]
  end
end
