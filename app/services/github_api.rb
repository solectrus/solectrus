class GithubApi
  def latest_release
    response =
      Net::HTTP.get_response(
        URI('https://api.github.com/repos/solectrus/solectrus/releases/latest'),
      )

    JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
  end
end
