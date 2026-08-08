# get_ranking reads the summaries, so it can only rank what has a row there.
# A sensor that is assembled in Ruby from other sensors' fields has none, and
# the ranking query falls back to adding those fields up - which is right only
# where the sensor really is their sum. It is not for
# house_power_without_custom (house MINUS custom), for any _pv split (base
# minus its grid share) or for grid_balance (revenue minus costs), and all
# three used to come back as sums: 14,936 Wh where get_totals said 6,800.
#
# None of these carries "r" in its tools string, none is reachable from the
# Top10 chart, and the conventions never promised them a ranking - they are
# exactly the sensors that are NOT summary-backed. So get_ranking says so
# instead of answering with a number that looks right.
describe McpServer::Tools::Ranking do
  # An error response carries plain text, a successful one JSON.
  def call(**args)
    response = described_class.call(**args)
    text = response.content.first[:text]

    [response.error?, response.error? ? text : JSON.parse(text, symbolize_names: true)]
  end

  before do
    create_summary(
      date: '2024-01-15',
      values: [
        [:house_power, :sum, 10_868],
        [:house_power_grid, :sum, 4_200],
        [:custom_power_01, :sum, 3_653],
        [:grid_import_power, :sum, 4_000],
        [:grid_export_power, :sum, 2_000],
      ],
    )
  end

  let(:timeframe) { '2024-01-15' }

  describe 'a sensor the summaries do not back' do
    it 'rejects house_power_without_custom instead of summing its parts' do
      error, data = call(sensor: 'house_power_without_custom', timeframe:)

      expect(error).to be(true)
      expect(data).to include('house_power_without_custom')
    end

    it 'names every affected sensor of the request at once' do
      _error, data =
        call(sensors: %w[house_power house_power_without_custom custom_power_01_pv], timeframe:)

      expect(data).to include('house_power_without_custom', 'custom_power_01_pv')
      expect(data).not_to include('house_power,')
    end

    it 'points at the tool that does answer for them' do
      _error, data = call(sensor: 'grid_balance', timeframe:)

      expect(data).to include('get_totals')
    end
  end

  describe 'a sensor the summaries do back' do
    it 'ranks a stored sensor' do
      error, data = call(sensor: 'house_power', timeframe:)

      expect(error).to be(false)
      expect(data[:results].first[:values].first).to eq(10_868)
    end

    # It has a stored field of its own, so it ranks - and now says so. The "r"
    # used to mark the curated Top 10 set of the UI instead, which left a
    # working call advertised as unavailable.
    it 'ranks a summary-backed split and advertises it with the r flag' do
      error, data = call(sensor: 'house_power_grid', timeframe:)

      expect(McpServer::SupportedTools.code(Sensor::Registry[:house_power_grid])).to include('r')
      expect(error).to be(false)
      expect(data[:results].first[:values].first).to eq(4_200)
    end

    it 'ranks a sensor that states its value as SQL' do
      error, data = call(sensor: 'grid_costs', timeframe:)

      expect(error).to be(false)
      expect(data[:results].first[:values]).not_to be_empty
    end
  end

  # The flag has to cover everything the UI already ranks, or the Top10 chart
  # would be offering sensors get_ranking refuses.
  it 'keeps every sensor the Top10 chart offers rankable' do
    expect(Sensor::Registry.top10_sensors.reject(&:rankable?)).to be_empty
  end
end
