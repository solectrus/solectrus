# Creates the InfluxDB bucket a parallel_tests worker writes to.
#
# spec/rails_helper.rb gives every worker its own bucket name. Only the base
# bucket exists in the container that bin/influxdb-restart.sh starts, so the
# numbered ones have to be created here. The Ruby client has no buckets API,
# hence the two plain HTTP calls.
module InfluxBucket
  class Error < StandardError
  end

  class << self
    def ensure_exists!
      return if ENV.fetch('TEST_ENV_NUMBER', nil).to_s.empty?

      response =
        post_json(
          '/api/v2/buckets',
          { orgID: org_id, name: config.bucket, retentionRules: [] },
        )

      # 422 means another worker created it first, or it survived from an
      # earlier run. Both are fine - the bucket is there either way.
      return if response.is_a?(Net::HTTPSuccess) || response.code == '422'

      raise Error,
            "Could not create InfluxDB bucket #{config.bucket}: " \
              "#{response.code} #{response.body}"
    end

    private

    def org_id
      response = get("/api/v2/orgs?#{URI.encode_www_form(org: config.org)}")
      unless response.is_a?(Net::HTTPSuccess)
        raise Error,
              "Could not look up InfluxDB org #{config.org}: " \
                "#{response.code} #{response.body}"
      end

      JSON.parse(response.body).dig('orgs', 0, 'id') ||
        raise(Error, "InfluxDB org #{config.org} does not exist")
    end

    def get(path) = request(Net::HTTP::Get.new(path))

    def post_json(path, body)
      request(Net::HTTP::Post.new(path)) { it.body = body.to_json }
    end

    def request(request)
      request['Authorization'] = "Token #{config.token}"
      request['Content-Type'] = 'application/json'
      yield request if block_given?

      Net::HTTP.start(
        config.host,
        config.port,
        use_ssl: config.schema == 'https',
      ) { |http| http.request(request) }
    end

    def config = Rails.configuration.x.influx
  end
end

InfluxBucket.ensure_exists!
