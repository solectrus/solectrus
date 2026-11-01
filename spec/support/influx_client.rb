# Writes and deletes InfluxDB data for the tests, over plain HTTP. The app only
# reads (see Influx::QueryApi), so neither needs a client gem. bin/llm-test
# requires this file as well.
#
# A point is a hash { name:, fields:, time: } with the time in seconds. The line
# protocol follows the rules of the former gem: the fields in sorted order, an
# Integer with the suffix "i", and a field without a key or a value left out.
# A point without a field is not written.
module InfluxClient
  class Error < StandardError
  end

  ESCAPE_KEY = /[\\, =]/
  ESCAPE_MEASUREMENT = /[\\, ]/
  ESCAPE_STRING = /[\\"]/
  private_constant :ESCAPE_KEY, :ESCAPE_MEASUREMENT, :ESCAPE_STRING

  class << self
    def write(points)
      lines = points.filter_map { line_of(it) }
      return if lines.empty?

      request('/api/v2/write', lines.join("\n"), precision: 's')
    end

    def delete(start, stop, predicate: nil)
      request(
        '/api/v2/delete',
        { start: start.iso8601, stop: stop.iso8601, predicate: }.compact.to_json,
        content_type: 'application/json',
      )
    end

    private

    def line_of(point)
      fields =
        point[:fields].sort.filter_map do |key, value|
          formatted = format_value(value)
          "#{escape(key, ESCAPE_KEY)}=#{formatted}" if formatted && key.to_s.present?
        end
      return if fields.empty?

      [escape(point[:name], ESCAPE_MEASUREMENT), fields.join(','), point[:time]].compact.join(' ')
    end

    def format_value(value)
      case value
      when nil then nil
      when String then %("#{escape(value, ESCAPE_STRING)}")
      when Integer then "#{value}i"
      when Float then value.to_s if value.finite?
      else value.to_s
      end
    end

    def escape(value, pattern) = value.to_s.gsub(pattern) { "\\#{it}" }

    def request(path, body, content_type: 'text/plain; charset=utf-8', **params)
      query = URI.encode_www_form(org: config.org, bucket: config.bucket, **params)
      request = Net::HTTP::Post.new("#{path}?#{query}")
      request['Authorization'] = "Token #{config.token}"
      request['Content-Type'] = content_type
      request.body = body

      response =
        Net::HTTP.start(config.host, config.port, use_ssl: config.schema == 'https') do |http|
          http.request(request)
        end
      return if response.is_a?(Net::HTTPSuccess)

      raise Error, "InfluxDB #{path} failed: #{response.code} #{response.body}"
    end

    def config = Rails.configuration.x.influx
  end
end
