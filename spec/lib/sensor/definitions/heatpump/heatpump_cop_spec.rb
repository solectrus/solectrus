describe Sensor::Definitions::HeatpumpCop do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { Sensor::Registry[:heatpump_cop] }

  before { stub_feature(:heatpump) }

  describe '#calculate' do
    it 'divides heating power by electrical power' do
      expect(sensor.calculate(heatpump_power: 1_000, heatpump_heating_power: 3_500)).to eq(3.5)
    end

    it 'returns nil without electrical power' do
      expect(sensor.calculate(heatpump_power: 0, heatpump_heating_power: 3_500)).to be_nil
    end
  end

  describe 'ranking' do
    def ranking(period:, start:, stop:)
      Sensor::Query::Ranking.new(:heatpump_cop, aggregation: :avg, period:, start:, stop:).call
    end

    before do
      create_summary(
        date: '2024-03-04',
        values: [[:heatpump_power, :sum, 2_000], [:heatpump_heating_power, :sum, 8_000]],
      )
      create_summary(
        date: '2024-03-05',
        values: [[:heatpump_power, :sum, 6_000], [:heatpump_heating_power, :sum, 12_000]],
      )
    end

    it 'ranks the days by their COP' do
      result = ranking(period: :day, start: Date.new(2024, 3, 1), stop: Date.new(2024, 3, 31))

      expect(result).to eq(
        [
          { date: Date.new(2024, 3, 4), value: 4.0 },
          { date: Date.new(2024, 3, 5), value: 2.0 },
        ],
      )
    end

    it 'ranks a week by the ratio of its sums, not by the mean of its days' do
      result = ranking(period: :week, start: Date.new(2024, 3, 4), stop: Date.new(2024, 3, 10))

      # (8000 + 12000) / (2000 + 6000) = 2.5, the mean of 4.0 and 2.0 is 3.0
      expect(result).to eq([{ date: Date.new(2024, 3, 4), value: 2.5 }])
    end
  end
end
