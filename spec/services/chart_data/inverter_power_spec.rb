describe ChartData::InverterPower do
  describe '#to_h' do
    subject(:to_h) do
      described_class.new(timeframe:, sensor: :inverter_power_1).to_h
    end

    let(:now) { Time.new('2024-04-17 11:00:00+02:00') }

    around { |example| travel_to(now, &example) }

    before do
      influx_batch do
        # Fill last hour with data
        12.times do |i|
          add_influx_point name: measurement_inverter_power_1,
                           fields: {
                             field_inverter_power_1 => 28_000,
                           },
                           time: 1.hour.ago + (5.minutes * (i + 1))
        end
      end

      create_summary(
        date: now.to_date,
        values: [[:inverter_power_1, :sum, 28_000]],
      )
    end

    context 'when timeframe is current MONTH' do
      let(:timeframe) { Timeframe.month }

      it 'contains value' do
        expect(to_h.dig(:datasets, 0, :data, now.day - 1)).to eq(28_000)
      end
    end

    context 'when timeframe is NOW' do
      let(:timeframe) { Timeframe.now }

      it 'contains value' do
        expect(to_h.dig(:datasets, 0, :data).last).to eq(28_000)
      end
    end
  end

  describe 'total inverter power' do
    subject(:to_h) do
      described_class.new(
        timeframe:,
        sensor: :inverter_power,
        variant: 'total',
      ).to_h
    end

    let(:timeframe) { Timeframe.month }
    let(:test_time) { Time.new('2024-06-20 12:00:00+02:00') }

    around { |example| travel_to(test_time, &example) }

    before do
      influx_batch do
        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => 30_000,
                         },
                         time: test_time.to_date.beginning_of_day

        add_influx_point name: measurement_inverter_power_2,
                         fields: {
                           field_inverter_power_2 => 25_000,
                         },
                         time: test_time.to_date.beginning_of_day
      end

      create_summary(
        date: test_time.to_date,
        values: [
          # No total present!
          [:inverter_power_1, :sum, 30_000],
          [:inverter_power_2, :sum, 25_000],
        ],
      )
    end

    it 'creates dataset for total only' do
      datasets = to_h[:datasets]
      dataset_ids = datasets.map { |d| d[:id] }

      expect(dataset_ids).to eq([:inverter_power])
    end

    it 'calculates total for each day' do
      data = to_h[:datasets].first[:data]

      (0..30).each do |i| # 30 days in June
        # On June 20th, the total should be 55,000
        # other days should be nil (not 0)
        expected = i == (20 - 1) ? 55_000 : nil

        expect(data[i]).to eq(expected)
      end
    end
  end

  describe 'stacked inverter power with difference calculation' do
    subject(:to_h) do
      described_class.new(
        timeframe:,
        sensor: :inverter_power,
        variant: 'split',
      ).to_h
    end

    let(:timeframe) { Timeframe.month }
    let(:test_time) { Time.new('2024-06-20 12:00:00+02:00') }

    around { |example| travel_to(test_time, &example) }

    before do
      influx_batch do
        add_influx_point name: measurement_inverter_power,
                         fields: {
                           field_inverter_power => 60_000,
                         },
                         time: test_time.to_date.beginning_of_day

        add_influx_point name: measurement_inverter_power_1,
                         fields: {
                           field_inverter_power_1 => 30_000,
                         },
                         time: test_time.to_date.beginning_of_day

        add_influx_point name: measurement_inverter_power_2,
                         fields: {
                           field_inverter_power_2 => 25_000,
                         },
                         time: test_time.to_date.beginning_of_day
      end

      create_summary(
        date: test_time.to_date,
        values: [
          [:inverter_power, :sum, 60_000],
          [:inverter_power_1, :sum, 30_000],
          [:inverter_power_2, :sum, 25_000],
        ],
      )
    end

    it 'creates datasets for individual inverters and difference' do
      datasets = to_h[:datasets]
      dataset_ids = datasets.map { |d| d[:id] }

      expect(dataset_ids).to include(
        :inverter_power_1,
        :inverter_power_2,
        :inverter_power_difference,
      )
    end

    it 'calculates significant difference correctly' do
      # Mock the chart method to ensure predictable data
      chart_data_service =
        described_class.new(
          timeframe:,
          sensor: :inverter_power,
          variant: 'split',
        )

      mock_chart = {
        inverter_power: [[test_time.to_i, 60_000]],
        inverter_power_1: [[test_time.to_i, 30_000]],
        inverter_power_2: [[test_time.to_i, 25_000]],
      }
      allow(chart_data_service).to receive(:chart).and_return(mock_chart)

      result = chart_data_service.to_h
      difference_dataset =
        result[:datasets].find { |d| d[:id] == :inverter_power_difference }
      difference_value = difference_dataset[:data][0] # First data point

      # 60,000 - (30,000 + 25,000) = 5,000 (8.33% - above 1% threshold)
      expect(difference_value).to eq(5_000)
    end

    it 'applies correct styling to difference dataset' do
      difference_dataset =
        to_h[:datasets].find { |d| d[:id] == :inverter_power_difference }

      expect(difference_dataset[:backgroundColor]).to eq('#5B807B')
      expect(difference_dataset[:stack]).to eq('InverterPower')
      expect(difference_dataset[:label]).to eq('Unassigned')
    end

    context 'with insignificant difference' do
      it 'does not show difference when below threshold' do
        # Mock the chart data to return minimal difference scenario
        chart_data_service =
          described_class.new(
            timeframe:,
            sensor: :inverter_power,
            variant: 'split',
          )

        # Mock the chart method to return data with minimal difference
        mock_chart = {
          inverter_power: [[test_time.to_i, 10_000]],
          inverter_power_1: [[test_time.to_i, 9_950]],
          inverter_power_2: [[test_time.to_i, 0]],
        }
        allow(chart_data_service).to receive(:chart).and_return(mock_chart)

        result = chart_data_service.to_h
        difference_dataset =
          result[:datasets].find { |d| d[:id] == :inverter_power_difference }
        difference_value = difference_dataset[:data][0] # First data point

        # 10,000 - (9,950 + 0) = 50 (0.5% of total - below 1% threshold)
        expect(difference_value).to be_nil
      end
    end
  end
end
