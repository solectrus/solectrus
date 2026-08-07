# The route scopes tiles to chart_enabled? sensors, and no power_splitter
# sensor defines a chart, so a live tile for a split is unreachable today (see
# spec/requests/tiles_request_spec.rb). This is the second line: the controller
# takes its sensor straight from the URL, so it must not query one live that
# has no instantaneous value, whatever the routing allows tomorrow.
describe TilesController do
  subject(:data) { controller.__send__(:data_now) }

  let(:controller) do
    described_class.new.tap do |instance|
      allow(instance).to receive_messages(sensor:, timeframe: Timeframe.now)
    end
  end

  before { allow(Sensor::Query::Latest).to receive(:new).and_call_original }

  context 'with an ordinary sensor' do
    let(:sensor) { Sensor::Registry[:house_power] }

    it 'reads it live' do
      data

      expect(Sensor::Query::Latest).to have_received(:new).with([:house_power])
    end
  end

  context 'with a power split' do
    let(:sensor) { Sensor::Registry[:house_power_grid] }

    it 'does not query it live' do
      data

      expect(Sensor::Query::Latest).not_to have_received(:new)
    end

    it 'reports no value, so the tile shows a dash' do
      expect(data.house_power_grid).to be_nil
    end
  end
end
