# list_sensors used to describe itself with "Call this first", and the server
# instructions repeated it. A client read that as an order and fetched the
# whole sensor index before nearly every question - one extra round trip and
# ~16 KB for a name it already knew. list_sensors is a DISCOVERY tool: needed
# to find a sensor or to resolve one the user named, not as a step before
# every call.
#
# The subject is the wording every client reads before it calls anything, so
# the spec covers the server instructions and all tools rather than one class.
describe 'MCP list_sensors as a discovery tool' do # rubocop:disable RSpec/DescribeClass
  # What a client can read as "fetch the index first". Kept as patterns rather
  # than exact strings: it is the instruction that must be gone, in any wording.
  def precedence_phrases
    [
      /call (this|list_sensors) first/i,
      /list_sensors first/i,
      /(start|begin) (with|by calling) list_sensors/i,
      /before (calling )?(any|another|every) (other )?tool/i,
    ]
  end

  describe 'server instructions' do
    subject(:instructions) { McpServer::Server.build.instructions }

    it 'does not demand list_sensors before the other tools' do
      precedence_phrases.each { expect(instructions).not_to match(it) }
    end

    it 'names list_sensors as discovery and says it is optional' do
      expect(instructions).to match(/discovery/i)
      expect(instructions).to match(/already know the sensor name/i)
    end
  end

  describe 'list_sensors' do
    subject(:description) { McpServer::Tools::ListSensors.description_value }

    it 'does not demand being called first' do
      precedence_phrases.each { expect(description).not_to match(it) }
    end

    it 'states what it is for' do
      expect(description).to match(/discover/i)
      expect(description).to match(/resolve a sensor the user mentioned/i)
    end

    it 'states that a known sensor name needs no lookup' do
      expect(description).to match(/already know the sensor name/i)
    end
  end

  describe 'every tool' do
    McpServer::Server.const_get(:TOOLS, false).each do |tool|
      it "#{tool.tool_name} does not require a previous list_sensors call" do
        precedence_phrases.each { expect(tool.to_h.to_json).not_to match(it) }
      end
    end
  end

  # The point of the wording change: a client that knows the name gets its
  # answer without the index. Validation of a bad name stays as it was, which
  # unknown_sensors_spec covers.
  describe 'calling a data tool with a known name' do
    it 'answers without a preceding list_sensors call' do
      data =
        Sensor::Data::Single.new(
          { battery_soc: 85.5 },
          timeframe: Timeframe.now,
          times: { battery_soc: Time.current },
        )
      allow(Sensor::Query::Latest).to receive(:new).and_return(
        instance_double(Sensor::Query::Latest, call: data),
      )

      response = McpServer::Tools::CurrentValues.call(server_context: nil, sensors: ['battery_soc'])
      parsed = JSON.parse(response.content.first[:text], symbolize_names: true)

      expect(response.error?).to be(false)
      expect(parsed[:values].pluck(:name)).to eq(['battery_soc'])
      expect(parsed).not_to have_key(:unknown_sensors)
    end
  end
end
