describe McpServer::RawData do
  let(:selection) do
    Influx::RawQuery::Selection.new(measurement: 'RAW_DEVICE', start: 1.hour.ago, stop: Time.current)
  end

  describe '.session' do
    # The slot taken here stands for another call that reads raw data
    it 'lets one call read at a time' do
      stub_const("#{described_class}::WAIT", 0.1)
      slot = described_class.const_get(:SLOT)
      slot.acquire

      expect { described_class.session { nil } }.to raise_error(McpServer::Tools::Base::Failure, /one after the other/)
    ensure
      slot.release
    end

    it 'frees the slot after the call' do
      described_class.session { nil }

      expect(described_class.session { :read }).to eq(:read)
    end

    it 'gives all queries of one call one deadline' do
      stub_const("#{described_class}::TIMEOUT", 0.1)

      expect do
        described_class.session do
          described_class.read { it.latest(selection) }
          sleep 0.2
          described_class.read { it.latest(selection) }
        end
      end.to raise_error(McpServer::Tools::Base::Failure, /did not answer/)
    end
  end

  describe '.read' do
    it 'stops an answer larger than the limit' do
      add_influx_point(name: 'RAW_DEVICE', fields: { level: 1.0 }, time: 1.minute.ago)
      stub_const("#{described_class}::MAX_BYTES", 10)

      expect { described_class.read { it.latest(selection) } }.to raise_error(
        McpServer::Tools::Base::Failure,
        /larger than 10 Bytes/,
      )
    end

    it 'says that a field changed its type, which no retry fixes' do
      allow(Influx.query_api).to receive(:query).and_raise(
        Influx::QueryError,
        "InfluxDB query failed: 400 Bad Request\n" \
          '{"message":"unsupported input type for mean aggregate: string"}',
      )

      expect { described_class.read { it.latest(selection) } }.to raise_error(
        McpServer::Tools::Base::Failure,
        /changed its type/,
      )
    end

    it 'logs the status of a failure, not the query with its values' do
      allow(Rails.logger).to receive(:warn)
      allow(Influx.query_api).to receive(:query).and_raise(
        Influx::QueryError,
        "InfluxDB query failed: 500 Internal Server Error\nbody\nFlux: r._value == \"private\"",
      )

      expect { described_class.read { it.latest(selection) } }.to raise_error(McpServer::Tools::Base::Failure)
      expect(Rails.logger).to have_received(:warn).with(
        'MCP raw query failed: Influx::QueryError: InfluxDB query failed: 500 Internal Server Error',
      )
    end
  end

  describe '.compact' do
    it 'cuts a long string' do
      value = described_class.compact('x' * 1000)

      expect(value.length).to eq(described_class::MAX_TEXT)
      expect(value).to end_with('…')
    end

    it 'keeps a short string' do
      expect(described_class.compact('idle')).to eq('idle')
    end
  end
end
