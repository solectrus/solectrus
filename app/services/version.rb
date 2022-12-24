class Version
  CHECK_URL = 'https://update.solectrus.de'.freeze
  public_constant :CHECK_URL

  def self.latest
    new.latest
  end

  def latest
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
          'User-Agent' => 'Solectrus',
          'X-Version' => Rails.configuration.x.git.commit_version,
          'Referer' => app_url,
        )

        http.request(request)
      end

    JSON.parse(response.body)['version'] if response.is_a?(Net::HTTPSuccess)
  rescue StandardError
    # Mainly ignore timeout errors, but other errors must not throw an exception
    nil
  end

  private

  def app_url
    return unless Rails.configuration.x.app_host

    "#{Rails.configuration.x.force_ssl ? 'https' : 'http'}://#{Rails.configuration.x.app_host}"
  end
end
