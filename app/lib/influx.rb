require 'net/http'
require 'connection_pool'

class Influx
  class QueryError < StandardError; end

  # A drop-in replacement for InfluxDB2::QueryApi#query that keeps its
  # connections open.
  #
  # The gem opens a fresh connection for every request and closes it again in
  # an ensure block (InfluxDB2::DefaultApi#_request), with no option to keep it
  # alive. Against a remote InfluxDB that handshake dominates: a trivial Flux
  # query cost ~250 ms, of which ~130 ms was connection setup, while the same
  # query against a local instance takes 3 ms.
  #
  # Only the transport is ours. Payload building and CSV parsing still come
  # from the gem, as do writes, health and version checks.
  class PooledQueryApi
    MAX_RETRIES = 2
    private_constant :MAX_RETRIES

    # A kept-alive connection can be dropped by the server or a proxy at any
    # time between two queries. Retrying makes sense for exactly that; a
    # timeout or a rejected query would only burn the timeout again.
    CONNECTION_ERRORS = [
      EOFError,
      IOError,
      Errno::ECONNABORTED,
      Errno::ECONNRESET,
      Errno::EPIPE,
      Net::HTTPBadResponse,
    ].freeze
    private_constant :CONNECTION_ERRORS

    QUERY_PATH = '/api/v2/query'.freeze
    private_constant :QUERY_PATH

    # How long a thread waits for a free connection before giving up. Only
    # reached when every connection is busy, which the pool size is chosen to
    # prevent in the first place.
    POOL_TIMEOUT = 5
    private_constant :POOL_TIMEOUT

    # Same signature and return value as InfluxDB2::QueryApi#query:
    # an Array of InfluxDB2::FluxTable.
    def query(query:)
      parser = InfluxDB2::FluxCsvParser.new(post(query))
      parser.parse
      parser.tables
    end

    def reset!
      pool_mutex.synchronize do
        @pool&.shutdown do |http|
          http.finish if http.started?
        rescue StandardError
          # Ignore close errors on broken connections
        end
        @pool = nil
      end
    end

    private

    def post(flux)
      pool.with { |http| execute(http, build_request(flux), flux) }
    rescue ConnectionPool::TimeoutError => e
      raise QueryError,
            "InfluxDB connection pool exhausted: #{e.message}\nFlux: #{flux}"
    end

    def build_request(flux)
      payload =
        InfluxDB2::Query.new(
          query: flux,
          dialect: InfluxDB2::QueryApi::DEFAULT_DIALECT,
          type: nil,
        )

      request =
        Net::HTTP::Post.new(
          "#{QUERY_PATH}?#{URI.encode_www_form(org: config.org)}",
        )
      request['Authorization'] = "Token #{config.token}"
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = "influxdb-client-ruby/#{InfluxDB2::VERSION}"
      request.body = payload.to_body.to_json
      request
    end

    def execute(http, request, flux)
      attempts = 0

      begin
        http.start unless http.started?
        check_response(http.request(request), flux)
      rescue *CONNECTION_ERRORS => e
        attempts += 1
        if attempts > MAX_RETRIES
          raise QueryError,
                "InfluxDB query failed after #{MAX_RETRIES} retries: #{e.message}\nFlux: #{flux}"
        end

        # Re-establish in place so the pool keeps handing out a usable object
        reconnect(http)
        retry
      end
    end

    def check_response(response, flux)
      unless response.is_a?(Net::HTTPSuccess)
        raise QueryError,
              "InfluxDB query failed: #{response.code} #{response.message}\n" \
                "#{response.body}\nFlux: #{flux}"
      end

      response.body
    end

    def reconnect(http)
      http.finish if http.started?
    rescue StandardError
      # The connection is being replaced anyway
    ensure
      http.start
    end

    def pool_mutex
      @pool_mutex ||= Mutex.new
    end

    # Blocks (up to POOL_TIMEOUT) once every connection is checked out rather
    # than opening overflow connections, mirroring QuestdbClient: a bounded
    # wait is the better failure mode than an unbounded number of sockets.
    def pool
      pool_mutex.synchronize do
        @pool ||=
          ConnectionPool.new(
            size: config.pool_size,
            timeout: POOL_TIMEOUT,
          ) { build_connection }
      end
    end

    def build_connection
      http = Net::HTTP.new(config.host, config.port)
      http.use_ssl = config.schema == 'https'
      http.open_timeout = 10
      http.read_timeout = 30
      http.write_timeout = 10
      # Net::HTTP only reuses a socket for this long after the last response;
      # beyond that it reconnects on its own instead of writing into a socket
      # the server may already have closed.
      http.keep_alive_timeout = 30
      http
    end

    def config
      Rails.configuration.x.influx
    end
  end

  config = Rails.configuration.x.influx
  @client =
    InfluxDB2::Client.new(
      "#{config.schema}://#{config.host}:#{config.port}",
      config.token,
      bucket: config.bucket,
      org: config.org,
      precision: InfluxDB2::WritePrecision::SECOND,
      use_ssl: config.schema == 'https',
      read_timeout: 30,
    )

  # Create query API once at initialization for thread-safety and performance
  @query_api = PooledQueryApi.new

  class << self
    attr_reader :client, :query_api

    delegate :ping, :health, to: :client
  end
end
