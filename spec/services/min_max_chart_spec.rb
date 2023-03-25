describe MinMaxChart do
  let(:measurement) { "Test#{described_class}" }
  let(:chart) do
    described_class.new(
      measurements: [measurement],
      fields: %w[bat_fuel_charge],
      average: true,
    )
  end

  let(:beginning) { 1.year.ago.beginning_of_year }

  around { |example| freeze_time(&example) }

  describe '#call' do
    subject(:result) { chart.call(timeframe) }

    context 'when timeframe is "now"' do
      before do
        influx_batch do
          # Battery goes from 60% to 0% in 1 hour
          60
            .downto(0)
            .each do |i|
              add_influx_point(
                name: measurement,
                fields: {
                  bat_fuel_charge: i,
                },
                time: i.minutes.ago,
              )
            end
        end
      end

      let(:timeframe) { Timeframe.now }

      it 'returns points' do
        expect(result).to be_a(Hash)

        expect(result['bat_fuel_charge']).to be_a(Array)
        expect(result['bat_fuel_charge'].size).to eq(60.minutes / 5.seconds)

        first_point = result['bat_fuel_charge'].first
        expect(first_point.last).to eq(60)

        last_point = result['bat_fuel_charge'].last
        expect(last_point.last).to eq(0)
      end
    end

    context 'when timeframe is "day"' do
      before do
        # Battery goes from 80% to 0%, 1% every 5 minutes
        influx_batch do
          time = Date.yesterday.beginning_of_day
          80
            .downto(0)
            .each do |i|
              add_influx_point(
                name: measurement,
                fields: {
                  bat_fuel_charge: i,
                },
                time: (time += 5.minutes),
              )
            end
        end
      end

      let(:timeframe) { Timeframe.new(Date.yesterday.iso8601) }

      it 'returns points' do
        expect(result).to be_a(Hash)

        expect(result['bat_fuel_charge']).to be_a(Array)
        expect(result['bat_fuel_charge'].size).to eq((24.hours / 5.minutes) - 1)

        first_point = result['bat_fuel_charge'].first
        expect(first_point).to eq(
          [Date.yesterday.beginning_of_day + 5.minutes, 80],
        )

        last_point = result['bat_fuel_charge'].last
        expect(last_point).to eq(
          [Date.yesterday.beginning_of_day + 1435.minutes, 0], # 1435 = 23:55
        )
      end
    end

    context 'when timeframe is "week"' do
      let(:start) { '2023-03-13'.to_date }
      let(:timeframe) { Timeframe.new('2023-W11') }

      before do
        influx_batch do
          # On every day of the week, battery is first 80%, then 40%
          date = start
          while date.cweek == start.cweek
            time = date.beginning_of_day
            23.times do |hour|
              add_influx_point(
                name: measurement,
                fields: {
                  bat_fuel_charge: hour < 12 ? 80 : 40,
                },
                time: (time += 1.hour),
              )
            end
            date += 1.day
          end
        end
      end

      it 'returns points' do
        expect(result).to be_a(Hash)

        expect(result['bat_fuel_charge']).to be_a(Array)
        expect(result['bat_fuel_charge'].size).to eq(7)

        first_point = result['bat_fuel_charge'].first
        expect(first_point).to eq([start, [40, 80]])

        last_point = result['bat_fuel_charge'].last
        expect(last_point).to eq([(start + 6.days).to_date, [40, 80]])
      end
    end

    context 'when timeframe is "month"' do
      let(:start) { '2023-02-01'.to_date }
      let(:timeframe) { Timeframe.new('2023-02') }

      before do
        influx_batch do
          # On every day of the month, battery is first 80%, then 40%
          date = start
          while date.month == start.month
            time = date.beginning_of_day
            23.times do |hour|
              add_influx_point(
                name: measurement,
                fields: {
                  bat_fuel_charge: hour < 12 ? 80 : 40,
                },
                time: (time += 1.hour),
              )
            end
            date += 1.day
          end
        end
      end

      it 'returns points' do
        expect(result).to be_a(Hash)

        expect(result['bat_fuel_charge']).to be_a(Array)
        expect(result['bat_fuel_charge'].size).to eq(28)

        first_point = result['bat_fuel_charge'].first
        expect(first_point).to eq([start, [40, 80]])

        last_point = result['bat_fuel_charge'].last
        expect(last_point).to eq([(start + 27.days).to_date, [40, 80]])
      end
    end

    context 'when timeframe is "year"' do
      let(:start) { '2022-01-01'.to_date }
      let(:timeframe) { Timeframe.new('2022') }

      before do
        influx_batch do
          # On every day of the year, battery is first 80%, then 40%
          date = start
          while date.year == start.year
            time = date.beginning_of_day

            23.times do |hour|
              add_influx_point(
                name: measurement,
                fields: {
                  bat_fuel_charge: hour < 12 ? 80 : 40,
                },
                time: (time += 1.hour),
              )
            end

            date += 1.day
          end
        end
      end

      it 'returns points' do
        expect(result).to be_a(Hash)

        expect(result['bat_fuel_charge']).to be_a(Array)
        expect(result['bat_fuel_charge'].size).to eq(12)

        first_point = result['bat_fuel_charge'].first
        expect(first_point).to eq([start, [40, 80]])

        last_point = result['bat_fuel_charge'].last
        expect(last_point).to eq([(start + 11.months).to_date, [40, 80]])
      end
    end

    context 'when timeframe is "all"' do
      let(:start) { 1.year.ago.beginning_of_year.to_date }
      let(:timeframe) { Timeframe.new('all', min_date: start) }

      before do
        influx_batch do
          # On every day of both years, battery is first 80%, then 40%
          date = start
          while date.year <= start.year + 1
            time = date.beginning_of_day

            23.times do |hour|
              add_influx_point(
                name: measurement,
                fields: {
                  bat_fuel_charge: hour < 12 ? 80 : 40,
                },
                time: (time += 1.hour),
              )
            end

            date += 1.day
          end
        end
      end

      it 'returns points' do
        expect(result).to be_a(Hash)

        expect(result['bat_fuel_charge']).to be_a(Array)
        expect(result['bat_fuel_charge'].size).to eq(2)

        first_point = result['bat_fuel_charge'].first
        expect(first_point).to eq([start, [40, 80]])

        last_point = result['bat_fuel_charge'].last
        expect(last_point).to eq([(start + 1.year).to_date, [40, 80]])
      end
    end
  end
end
