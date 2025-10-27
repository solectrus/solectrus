Sensor::Registry[:autarky]

describe Sensor::Definitions::Autarky do # rubocop:disable RSpec/SpecFilePathFormat
  let(:sensor) { described_class.new }

  describe '#calculate' do
    let(:data) { { grid_import_power:, total_consumption: } }

    let(:timeframe) { Timeframe.now }

    context 'when total_consumption is zero' do
      let(:grid_import_power) { 50 }
      let(:total_consumption) { 0 }

      it 'returns nil' do
        expect(sensor.calculate(**data)).to be_nil
      end
    end

    context 'when total_consumption is non-zero' do
      let(:grid_import_power) { 50 }
      let(:total_consumption) { 100 }

      it 'returns the correct calculation' do
        expect(sensor.calculate(**data)).to eq(50.0)
      end
    end
  end

  describe 'SQL integration' do
    subject(:result) { query.call }

    describe 'for avg of single day' do
      let(:query) do
        Sensor::Query::Total.new(Timeframe.new('2024-06-15')) do |q|
          q.avg :autarky
        end
      end

      context 'when dependencies are present' do
        before do
          create_summary(
            date: '2024-06-15',
            values: [
              [:grid_import_power, :sum, 1_000],
              [:house_power, :sum, 4_000],
            ],
          )
        end

        it 'returns calculation' do
          # total_consumption is calculated from house_power (4000)
          # autarky = (total_consumption - grid_import_power) / total_consumption * 100
          # autarky = (4000 - 1000) / 4000 * 100 = 75%
          expect(result.autarky).to eq(75.0)
        end
      end
    end

    describe 'for avg of avg of a month' do
      let(:query) do
        Sensor::Query::Total.new(Timeframe.new('2024-06')) do |q|
          q.avg :autarky, :avg
        end
      end

      context 'when dependencies are present' do
        before do
          create_summary(
            date: '2024-06-15',
            values: [
              [:grid_import_power, :sum, 1_000],
              [:house_power, :sum, 10_000],
            ],
          )

          create_summary(
            date: '2024-06-16',
            values: [
              [:grid_import_power, :sum, 3_000],
              [:house_power, :sum, 12_000],
            ],
          )
        end

        it 'returns calculation' do
          # Day 1: (10k - 1k) / 10k * 100 = 90%
          # Day 2: (12k - 3k) / 12k * 100 = 75%
          # Total: (22k - 4k) / 22k * 100 =  81.8181..
          expect(result.autarky).to eq(82)
        end
      end
    end

    describe 'Forbidden queries' do
      %i[min max].each do |agg|
        context "when #{agg} of single day" do
          it 'raises ArgumentError during query initialization' do
            expect do
              Sensor::Query::Total.new(Timeframe.new('2024-06-15')) do |q|
                q.public_send(agg, :autarky)
              end
            end.to raise_error(
              ArgumentError,
              /Sensor autarky doesn't support meta aggregation #{agg}/,
            )
          end
        end
      end
    end
  end
end
