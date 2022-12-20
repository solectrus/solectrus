class Version
  def self.latest
    new.latest
  end

  def latest
    uri = URI('https://update.solectrus.de')
    response =
      Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request.initialize_http_header(
          'Accept' => 'application/json',
          'User-Agent' => 'Solectrus',
          'X-Version' => Rails.configuration.x.git.commit_version,
          'Referer' => Rails.configuration.x.app_host,
        )

        http.request(request)
      end

    JSON.parse(response.body)['version'] if response.is_a?(Net::HTTPSuccess)
  end
end
