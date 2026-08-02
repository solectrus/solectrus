# conventions.suffixes asks clients to form _pv/_grid names themselves and
# calls such a name "a good guess, not a guarantee". A guess that misses used
# to discard the whole call: asking for house_power_pv, house_power_grid and
# battery_discharging_power_pv got nothing back, though two of the three were
# valid. A wrong guess has to cost its own entry instead.
#
# The subject is the shared contract of every tool taking a `sensors` array,
# not one class.
describe 'MCP unknown sensor names' do # rubocop:disable RSpec/DescribeClass
  # One valid name and one typo, through every tool that takes a list.
  {
    'get_current_values' =>
      ->(sensors) { McpServer::Tools::CurrentValues.call(sensors:) },
    'get_totals' =>
      ->(sensors) { McpServer::Tools::Totals.call(timeframe: '2024-06-15', sensors:) },
    'get_ranking' =>
      ->(sensors) { McpServer::Tools::Ranking.call(timeframe: '2024-06-15', sensors:) },
    'get_series' =>
      lambda do |sensors|
        McpServer::Tools::Series.call(timeframe: '2024-06-15', sensors:, resolution: '1h')
      end,
    'get_sensor_details' =>
      ->(sensors) { McpServer::Tools::SensorDetails.call(sensors:) },
  }.each do |tool, call|
    describe tool do
      def parse(response)
        JSON.parse(response.content.first[:text], symbolize_names: true)
      end

      it 'answers the valid sensor and reports the unknown one' do
        response = call.call(%w[house_power hause_power])

        expect(response.error?).to be(false)
        expect(parse(response)).to include(unknown_sensors: %w[hause_power])
      end

      it 'says nothing about unknown sensors when every name resolved' do
        expect(parse(call.call(%w[house_power]))).not_to include(:unknown_sensors)
      end

      it 'fails when no name is left' do
        response = call.call(%w[hause_power])

        expect(response.error?).to be(true)
        expect(response.content.first[:text]).to include('list_sensors')
      end
    end
  end
end
