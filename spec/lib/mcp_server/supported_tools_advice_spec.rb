# A rejection is only useful if what it sends the client to actually answers.
# The messages used to name tools from memory, which was right for the sensor
# their author had in mind and wrong for the next one: get_totals told a client
# asking for power_balance to "use get_current_values ... or get_series", and
# both reject it too. Nothing could notice, because the advice was a string.
#
# So the property is checked over every sensor this instance has, against the
# same matrix list_sensors publishes.
describe McpServer::SupportedTools do
  # Only the tools that gate on the sensor/tool matrix. get_forecast takes no
  # sensor argument at all.
  let(:gated_tools) { %i[current series totals ranking] }

  # The tools a message points the client AT. The rejecting tool itself is
  # excluded: every message opens by naming it ("get_totals has no total for
  # these sensors"), which is a statement about what failed, not advice.
  def tools_named_in(text, except: nil)
    McpServer::SupportedTools::LETTERS.each_key.select do |flag|
      flag != except && text.include?(McpServer::Facts.tool_name(flag))
    end
  end

  def rejection_text(sensor, tool)
    McpServer::Tools::Base.__send__(:enforce_supported!, [sensor], tool)
    nil
  rescue ArgumentError => e
    e.message
  end

  # Every (sensor, tool) pair the matrix says is unsupported, paired with the
  # message the tool produces for it.
  def each_rejection
    Sensor::Config.sensors.each do |sensor|
      gated_tools.each do |tool|
        next if McpServer::SupportedTools.supports?(sensor, tool)

        text = rejection_text(sensor, tool)
        yield sensor, tool, text
      end
    end
  end

  it 'rejects exactly what the advertised matrix says it rejects' do
    silent =
      Sensor::Config.sensors.flat_map do |sensor|
        gated_tools.filter_map do |tool|
          supported = described_class.supports?(sensor, tool)
          raised = !rejection_text(sensor, tool).nil?

          "#{sensor.name}/#{tool}" if supported == raised
        end
      end

    expect(silent).to be_empty
  end

  it 'never advises a tool that rejects the same sensor' do
    misdirected = []

    each_rejection do |sensor, tool, text|
      tools_named_in(text, except: tool).each do |advised|
        next if described_class.supports?(sensor, advised)

        misdirected << "#{tool} sends #{sensor.name} to #{McpServer::Facts.tool_name(advised)}"
      end
    end

    expect(misdirected).to be_empty
  end

  # A sensor no tool answers for has to be told so. Left unsaid, a client works
  # through the list one call at a time and concludes the instance is broken.
  it 'says so where nothing answers, instead of naming a tool' do
    unanswerable =
      Sensor::Config.sensors.select do |sensor|
        described_class.code(sensor).empty?
      end

    expect(unanswerable.map(&:name)).to contain_exactly(
      :power_balance,
      :heatpump_cop_scatter,
    )

    unanswerable.each do |sensor|
      text = rejection_text(sensor, :current)

      expect(text).to include('No other tool answers for it')
      expect(tools_named_in(text, except: :current)).to be_empty
    end
  end

  it 'names the rejected sensor in every message' do
    each_rejection do |sensor, _tool, text|
      expect(text).to include(sensor.name.to_s)
    end
  end

  # A rejection ends the call, so the names resolve_sensors skipped would be
  # lost with it - and the client learns about its typo only on a second round
  # trip, after removing the sensor that was rejected.
  it 'carries the skipped unknown names into the rejection' do
    response =
      McpServer::Tools::Totals.call(
        server_context: nil,
        timeframe: '2024-06-15',
        sensors: %w[house_power power_balance nonexistent_sensor],
      )

    expect(response.error?).to be(true)
    expect(response.content.first[:text]).to include(
      'power_balance',
      'nonexistent_sensor',
    )
  end
end
