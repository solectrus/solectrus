describe ChartData::HousePower do
  subject(:to_h) { described_class.new(timeframe:).to_h }

  let(:now) { Time.new('2024-04-17 11:00:00+02:00') }

  around { |example| travel_to(now, &example) }

  before do
    influx_batch do
      # Fill last hour with data
      12.times do |i|
        add_influx_point name: measurement_heatpump_power,
                         fields: {
                           field_heatpump_power => 10_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_heatpump_power_grid,
                         fields: {
                           field_heatpump_power_grid => 900,
                         },
                         time: 1.hour.ago + (5.minutes * i)

        add_influx_point name: measurement_house_power,
                         fields: {
                           field_house_power => 15_000, # Includes heatpump of 10_000
                         },
                         time: 1.hour.ago + (5.minutes * i)
      end
    end
  end

  context 'when house_power_grid data is present' do
    before do
      influx_batch do
        # Fill last hour with data
        12.times do |i|
          add_influx_point name: measurement_house_power_grid,
                           fields: {
                             field_house_power_grid => 300,
                           },
                           time: 1.hour.ago + (5.minutes * i)
        end
      end
    end

    context 'when timeframe is current MONTH' do
      let(:timeframe) { Timeframe.month }

      context 'when power_splitter is enabled' do
        before do
          allow(ApplicationPolicy).to receive(:power_splitter?).and_return(true)
        end

        it 'returns three datasets' do
          expect(to_h).to be_a(Hash)
          expect(to_h).to include(:datasets, :labels)
          expect(to_h[:datasets].length).to eq(3)

          expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(5)

          expect(to_h.dig(:datasets, 1, :data, now.day - 1)).to be_within(
            0.001,
          ).of(0.3)

          expect(to_h.dig(:datasets, 2, :data, now.day - 1)).to be_within(
            0.001,
          ).of(4.7)
        end
      end

      context 'when power_splitter is NOT enabled' do
        it 'returns one datasets' do
          expect(to_h).to be_a(Hash)
          expect(to_h).to include(:datasets, :labels)
          expect(to_h[:datasets].length).to eq(1)

          expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(5)
        end
      end
    end

    context 'when timeframe is NOW' do
      let(:timeframe) { Timeframe.now }

      it 'returns single dataset' do
        expect(to_h[:datasets].length).to eq(1)
        expect(to_h.dig(:datasets, 0, :data).last).to eq(5)
      end
    end
  end

  context 'when house_power_grid data is missing' do
    context 'when timeframe is current MONTH' do
      let(:timeframe) { Timeframe.month }

      it 'returns single dataset' do
        expect(to_h).to be_a(Hash)
        expect(to_h).to include(:datasets, :labels)
        expect(to_h[:datasets].length).to eq(1)

        expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(5)
      end
    end

    context 'when timeframe is NOW' do
      let(:timeframe) { Timeframe.now }

      it 'returns single dataset' do
        expect(to_h[:datasets].length).to eq(1)
        expect(to_h.dig(:datasets, 0, :data).last).to eq(5)
      end
    end
  end
end
