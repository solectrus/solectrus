require 'net/http'
require 'connection_pool'

class Influx
  class QueryError < StandardError; end

  # Runs Flux queries over a pool of kept-alive connections.
  #
  # The former influxdb-client gem opened a fresh connection for every request
  # and closed it again in an ensure block (InfluxDB2::DefaultApi#_request),
  # with no option to keep it alive. Against a remote InfluxDB that handshake
  # dominates: a trivial Flux query cost ~250 ms, of which ~130 ms was
  # connection setup, while the same query against a local instance takes
  # 3 ms.
  #
  # The app only reads, so it needs no client gem: Influx::CsvParser parses
  # the responses. The tests write over plain HTTP as well (see
  # spec/support/influx_client.rb).
  class QueryApi
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
    PING_PATH = '/ping'.freeze
    HEALTH_PATH = '/health'.freeze
    USER_AGENT = 'SOLECTRUS'.freeze
    private_constant :QUERY_PATH, :PING_PATH, :HEALTH_PATH, :USER_AGENT

    # The annotated CSV that Influx::CsvParser reads
    DIALECT = {
      header: true,
      delimiter: ',',
      annotations: %w[datatype group default],
      commentPrefix: '#',
      dateTimeFormat: 'RFC3339',
    }.freeze
    private_constant :DIALECT

    # How long a thread waits for a free connection before giving up. Only
    # reached when every connection is busy, which the pool size is chosen to
    # prevent in the first place.
    POOL_TIMEOUT = 5
    private_constant :POOL_TIMEOUT

    def initialize
      @pool = build_pool
    end

    # Returns the response rows as plain hashes (column => value), flattened
    # across Flux tables. See Influx::CsvParser for why not FluxTable objects.
    def query(flux)
      CsvParser.call(post(flux))
    end

    # Whether InfluxDB answers. Raises when it cannot be reached.
    def ping?
      get(PING_PATH)
      true
    end

    # The version that InfluxDB reports, for example "v2.9.1"
    def version
      JSON.parse(get(HEALTH_PATH))['version']
    end

    # The pool stays the same object and opens fresh connections on the next
    # checkout.
    def reset!
      pool.reload { |http| finish_quietly(http) }
    end

    private

    attr_reader :pool

    def post(flux)
      perform(build_request(flux), "Flux: #{flux}")
    end

    # A connection of its own, outside the pool: the health check must answer
    # also while the queries of a summary build hold every pooled connection
    def get(path)
      request = Net::HTTP::Get.new(path)
      request['User-Agent'] = USER_AGENT
      build_connection.start do |http|
        check_response(http.request(request), "Path: #{path}")
      end
    end

    def perform(request, context)
      pool.with { |http| execute(http, request, context) }
    rescue ConnectionPool::TimeoutError => e
      raise QueryError,
            "InfluxDB connection pool exhausted: #{e.message}\n#{context}"
    end

    def build_request(flux)
      request =
        Net::HTTP::Post.new(
          "#{QUERY_PATH}?#{URI.encode_www_form(org: config.org)}",
        )
      request['Authorization'] = "Token #{config.token}"
      request['Content-Type'] = 'application/json'
      request['User-Agent'] = USER_AGENT
      request.body = { query: flux, dialect: DIALECT }.to_json
      request
    end

    def execute(http, request, context)
      attempts = 0

      begin
        http.start unless http.started?
        check_response(http.request(request), context)
      rescue *CONNECTION_ERRORS => e
        attempts += 1
        if attempts > MAX_RETRIES
          raise QueryError,
                "InfluxDB query failed after #{MAX_RETRIES} retries: #{e.message}\n#{context}"
        end

        # Re-establish in place so the pool keeps handing out a usable object
        reconnect(http)
        retry
      end
    end

    def check_response(response, context)
      unless response.is_a?(Net::HTTPSuccess)
        raise QueryError,
              "InfluxDB query failed: #{response.code} #{response.message}\n" \
                "#{response.body}\n#{context}"
      end

      response.body
    end

    def reconnect(http)
      finish_quietly(http)
    ensure
      http.start
    end

    # Closing a dropped connection can raise, and the socket is going away
    # either way.
    def finish_quietly(http)
      http.finish if http.started?
    rescue StandardError
      # The connection is broken or already gone, nothing left to close
    end

    # The pool opens no connection here, only on the first checkout. It blocks
    # (up to POOL_TIMEOUT) once every connection is checked out rather than
    # opening overflow connections, mirroring QuestdbClient: a bounded wait is
    # the better failure mode than an unbounded number of sockets.
    def build_pool
      ConnectionPool.new(size: config.pool_size, timeout: POOL_TIMEOUT) do
        build_connection
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

  # Create query API once at initialization for thread-safety and performance
  @query_api = QueryApi.new

  class << self
    attr_reader :query_api

    delegate :query, :ping?, :version, to: :query_api
  end
end
