describe Sensor::Chart::OutdoorTemp do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.day }

  before do
    freeze_time

    add_influx_point(
      name: Sensor::Config.measurement(:outdoor_temp),
      fields: {
        Sensor::Config.field(:outdoor_temp) => 12.5,
      },
      time: 30.minutes.ago,
    )
  end

  context 'when there is no forecast for today' do
    it 'draws the forecast as an empty dataset' do
      forecast = chart.data[:datasets].find { it[:id] == 'outdoor_temp_forecast' }

      expect(forecast[:data].compact).to be_empty
    end

    it 'still draws the measured temperature' do
      measured = chart.data[:datasets].find { it[:id] == 'outdoor_temp' }

      expect(measured[:data].compact).to include(12.5)
    end
  end
end
