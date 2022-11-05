class GithubApi
  def latest_release
    res =
      Net::HTTP.get_response(
        URI('https://api.github.com/repos/solectrus/solectrus/releases/latest'),
      )
    return {} unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end
end
