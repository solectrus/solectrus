describe ChartData::WallboxPower do
  subject(:to_h) { described_class.new(timeframe:).to_h }

  let(:now) { Time.new('2024-04-17 11:00:00 +02:00') }

  around { |example| travel_to(now, &example) }

  before do
    influx_batch do
      # Fill last hour with data
      12.times do |i|
        add_influx_point name: measurement_wallbox_power,
                         fields: {
                           field_wallbox_power => 27_000,
                         },
                         time: 1.hour.ago + (5.minutes * i)
      end
    end
  end

  context 'when wallbox_power_grid data is present' do
    before do
      influx_batch do
        # Fill last hour with data
        12.times do |i|
          add_influx_point name: measurement_wallbox_power_grid,
                           fields: {
                             field_wallbox_power_grid => 900,
                           },
                           time: 1.hour.ago + (5.minutes * i)
        end
      end

      create_summary(
        date: now.to_date,
        values: [
          [:wallbox_power, :sum, 27_000],
          [:wallbox_power_grid, :sum, 900],
        ],
      )
    end

    context 'when timeframe is current MONTH' do
      let(:timeframe) { Timeframe.month }

      context 'when power_splitter is enabled' do
        before do
          allow(ApplicationPolicy).to receive(:power_splitter?).and_return(true)
        end

        it 'returns three datasets' do
          expect(to_h[:datasets].length).to eq(3)

          expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(27_000)
          expect(to_h.dig(:datasets, 1, :data, now.day - 1)).to eq(900)
          expect(to_h.dig(:datasets, 2, :data, now.day - 1)).to eq(26_100)
        end
      end

      context 'when power_splitter is NOT enabled' do
        it 'returns one datasets' do
          expect(to_h[:datasets].length).to eq(1)

          expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(27_000)
        end
      end
    end

    context 'when timeframe is NOW' do
      let(:timeframe) { Timeframe.now }

      it 'returns one dataset' do
        expect(to_h[:datasets].length).to eq(1)

        expect(to_h.dig(:datasets, 0, :data).last).to eq(27_000)
      end
    end
  end

  context 'when wallbox_power_grid data is missing' do
    context 'when timeframe is current MONTH' do
      let(:timeframe) { Timeframe.month }

      before do
        create_summary(
          date: now.to_date,
          values: [
            [:wallbox_power, :sum, 27_000],
            [:wallbox_power_grid, :sum, 900],
          ],
        )
      end

      it 'returns one datasets' do
        expect(to_h[:datasets].length).to eq(1)

        expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(27_000)
      end
    end

    context 'when timeframe is NOW' do
      let(:timeframe) { Timeframe.now }

      it 'returns one dataset' do
        expect(to_h[:datasets].length).to eq(1)

        expect(to_h.dig(:datasets, 0, :data).last).to eq(27_000)
      end
    end
  end
end
