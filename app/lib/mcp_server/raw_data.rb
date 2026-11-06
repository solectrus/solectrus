module McpServer
  # What list_measurements and get_raw_series share: the read with its timeout
  # and its errors, the fields MCP does not offer, and the shape of a raw value.
  module RawData
    module_function

    # The time one tool call has for all its raw queries together. A query
    # that runs longer is cut off, and InfluxDB cancels it. The limits of the
    # tools keep each query far below it: this is a safety net, not a budget.
    TIMEOUT = 5
    public_constant :TIMEOUT

    # The largest answer of InfluxDB that a raw query reads. The limits of the
    # tools keep a normal answer far below it: 3000 points are about 0.5 MB.
    # What is larger is stopped while it arrives, before it fills the memory
    # of a small computer.
    MAX_BYTES = 4.megabytes
    public_constant :MAX_BYTES

    # How long a tool call waits while another one reads raw data
    WAIT = 5
    public_constant :WAIT

    # One tool call reads raw data at a time, in each process. A client that
    # sends several calls at once would otherwise give InfluxDB several
    # expensive queries together, and keep the web threads busy.
    SLOT = Concurrent::Semaphore.new(1)
    private_constant :SLOT

    # A name is compared with, never parsed (see Influx::RawQuery.literal), so
    # this only keeps out what no InfluxDB name holds.
    MAX_NAME_LENGTH = 256
    private_constant :MAX_NAME_LENGTH

    # A string value in a response is cut after this many characters. A
    # state or a message is shorter, a JSON document or a log is not.
    MAX_TEXT = 200
    public_constant :MAX_TEXT

    # The admin allows the raw tools in the settings
    def enabled? = Setting.mcp_raw_data

    # Runs a tool call that reads raw data: it waits for the slot, and its
    # queries share one deadline. A nested call runs in the session around it.
    def session
      return yield if deadline

      unless SLOT.try_acquire(1, WAIT)
        raise Tools::Base::Failure,
              'Another call is reading raw data. Send the calls one after the other.'
      end

      begin
        self.deadline = clock + TIMEOUT
        yield
      ensure
        self.deadline = nil
        SLOT.release
      end
    end

    # Runs the block with an Influx::RawQuery and turns a failure of InfluxDB
    # into a message the client can act on. The details go to the log only:
    # the class and the status, not the query, which can hold values of the
    # data.
    def read(&)
      session { yield Influx::RawQuery.new(timeout: deadline - clock, max_bytes: MAX_BYTES) }
    rescue Net::ReadTimeout
      raise Tools::Base::Failure,
            "InfluxDB did not answer within #{TIMEOUT} seconds, so the query was " \
              'cancelled. Ask for a shorter window, fewer fields or a coarser resolution.'
    rescue Influx::ResponseTooLarge
      raise Tools::Base::Failure,
            "The answer is larger than #{ActiveSupport::NumberHelper.number_to_human_size(MAX_BYTES)}. Ask for fewer fields, " \
              'one series (`tags`), a shorter window or a coarser resolution.'
    rescue Influx::QueryError, Net::OpenTimeout, SystemCallError, SocketError, IOError, OpenSSL::SSL::SSLError => e
      raise Tools::Base::Failure, MIXED_TYPES if e.message.include?('unsupported input type')

      Rails.logger.warn("MCP raw query failed: #{e.class}: #{e.message.lines.first&.strip}")
      raise Tools::Base::Failure, 'InfluxDB could not answer this query. Try again later.'
    end

    # The type of a field comes from its newest sample. An older sample of
    # another type makes InfluxDB reject an aggregation.
    MIXED_TYPES =
      'A field changed its type in this window (number and text), so it cannot be ' \
        'aggregated. Ask for `last`, `changes`, or a window after the change.'.freeze
    private_constant :MIXED_TYPES

    def deadline = ActiveSupport::IsolatedExecutionState[:mcp_raw_deadline]

    def deadline=(value)
      ActiveSupport::IsolatedExecutionState[:mcp_raw_deadline] = value
    end

    def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    private_class_method :deadline=, :clock

    # A name of a measurement, a field or a tag
    def name!(value, label)
      name = value.to_s
      if name.empty? || name.length > MAX_NAME_LENGTH || name.match?(/[[:cntrl:]]/)
        raise ArgumentError, "Invalid #{label}: #{value.inspect}."
      end

      name
    end

    # The fields of one measurement that MCP does not offer, see
    # McpServer::Sensors.withheld_fields
    def withheld(measurement)
      McpServer::Sensors.withheld_fields.filter_map { |pair_measurement, field| field if pair_measurement == measurement }
    end

    # The window list_measurements reads by default, and list_sensors when it
    # looks for data that no sensor reads
    LOOKBACK = 30.days
    public_constant :LOOKBACK

    # { measurement => [field, ...] } of the data in the window that MCP
    # offers
    def fields(start:, stop:)
      withheld = McpServer::Sensors.withheld_fields
      read { it.fields(start:, stop:) }.to_h do |measurement, names|
        [measurement, names.reject { withheld.include?([measurement, it]) }]
      end
    end

    # The measurements that `query` names, { measurement => [field, ...] }:
    # by their own name (with no field listed), or by the name of a field (with
    # the fields that matched). A user names a device as often as a value of
    # one, and a temperature is a field of the device that measures it.
    def matches(fields, query)
      part = query.to_s.strip.downcase

      fields.sort.filter_map do |measurement, names|
        next [measurement, []] if measurement.downcase.include?(part)

        hits = names.select { it.downcase.include?(part) }
        [measurement, hits] if hits.any?
      end.to_h
    end

    # #matches within the default LOOKBACK
    def search(query)
      stop = Time.current.change(usec: 0)
      matches(fields(start: stop - LOOKBACK, stop:), query)
    end

    # What a search that found nothing says, in list_sensors and in
    # list_measurements alike: an answer, not a reason to search on
    def nothing_note(query)
      "No InfluxDB measurement or field name contains \"#{query.to_s.strip}\". Without a sensor " \
        'for it either (list_sensors), this instance holds no such data: say so, and answer ' \
        'the rest of the question in the same reply.'
    end

    # The distinct tag sets of the rows
    def series(rows) = rows.map { Influx::RawQuery.tags_of(it) }.uniq

    # A float with what it says and nothing more: a value written as a 32-bit
    # float arrives as 12.300000190734863. Six significant digits, but never
    # fewer than four decimals, so a large counter keeps its last digit.
    #
    # JSON has no infinity, so that one goes out as text. A long string is cut
    # after MAX_TEXT characters.
    def compact(value)
      return value.truncate(MAX_TEXT, omission: '…') if value.is_a?(String)
      return value unless value.is_a?(Float)
      return value.to_s unless value.finite?
      return value if value.zero?

      digits = [4, 5 - Math.log10(value.abs).floor].max
      value.round(digits)
    end
  end
end
