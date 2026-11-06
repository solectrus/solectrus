class Influx
  # The bounds of one query, see Influx::QueryApi#query. The deadline holds
  # for the whole query, retries included.
  class QueryLimits
    def initialize(timeout:, max_bytes:)
      @deadline = now + timeout if timeout
      @max_bytes = max_bytes
    end

    # Gives the connection the time that is left as its read timeout, so a
    # single read cannot outlast the deadline
    def arm!(http)
      return unless @deadline

      left = @deadline - now
      raise Net::ReadTimeout, 'InfluxDB query took too long' unless left.positive?

      http.read_timeout = left
    end

    # [response, body]. The body arrives in chunks and each one is checked,
    # so a query that runs too long or answers too much stops while it is
    # read.
    def request(http, request)
      body = +''
      response =
        http.request(request) do |res|
          res.read_body do |chunk|
            body << chunk
            check!(body.bytesize)
          end
        end
      [response, body]
    end

    private

    # A slow answer still sends something within each read timeout, so only
    # this check stops it
    def check!(bytes)
      raise Net::ReadTimeout, 'InfluxDB query took too long' if @deadline && now > @deadline
      raise ResponseTooLarge, "InfluxDB answer larger than #{@max_bytes} bytes" if @max_bytes && bytes > @max_bytes
    end

    def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
