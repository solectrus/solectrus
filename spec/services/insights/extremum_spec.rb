describe Insights::Extremum do
  subject(:service) { described_class.new(sensor:, timeframe:, aggregation:) }

  let(:sensor) { Sensor::Registry[:inverter_power] }
  let(:timeframe) { Timeframe.new('2025-10') }
  let(:aggregation) { :max }

  describe '#initialize' do
    context 'with valid arguments' do
      it 'creates an instance' do
        expect(service).to be_a(described_class)
        expect(service.sensor).to eq(sensor)
        expect(service.timeframe).to eq(timeframe)
        expect(service.aggregation).to eq(aggregation)
      end
    end

    context 'when sensor is not a Sensor::Definitions::Base' do
      let(:sensor) { :not_a_sensor }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when sensor is nil' do
      let(:sensor) { nil }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when timeframe is not a Timeframe' do
      let(:timeframe) { '2025-10' }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when timeframe is nil' do
      let(:timeframe) { nil }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when aggregation is not :max or :min' do
      let(:aggregation) { :sum }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when aggregation is nil' do
      let(:aggregation) { nil }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end

    context 'when aggregation is a string' do
      let(:aggregation) { 'max' }

      it 'raises ArgumentError' do
        expect { service }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#call' do
    subject(:call) { service.call }

    before do
      travel_to Date.new(2025, 10, 25) # Set date after all test data

      create_summary(
        date: Date.new(2025, 10, 5),
        values: [
          [:inverter_power, :sum, 15_000],
          [:inverter_power_1, :sum, 10_000],
          [:inverter_power_2, :sum, 5_000],
        ],
      )
      create_summary(
        date: Date.new(2025, 10, 12),
        values: [
          [:inverter_power, :sum, 25_000],
          [:inverter_power_1, :sum, 15_000],
          [:inverter_power_2, :sum, 10_000],
        ],
      )
      create_summary(
        date: Date.new(2025, 10, 20),
        values: [
          [:inverter_power, :sum, 8_000],
          [:inverter_power_1, :sum, 5_000],
          [:inverter_power_2, :sum, 3_000],
        ],
      )
    end

    context 'when aggregation is :max' do
      let(:aggregation) { :max }

      it 'returns the day with maximum value' do
        expect(call).to eq({ date: Date.new(2025, 10, 12), value: 25_000 })
      end
    end

    context 'when aggregation is :min' do
      let(:aggregation) { :min }

      it 'returns the day with minimum value' do
        expect(call).to eq({ date: Date.new(2025, 10, 20), value: 8_000 })
      end
    end

    context 'when timeframe is a single day' do
      let(:timeframe) { Timeframe.new('2025-10-12') }

      it 'returns nil' do
        expect(call).to be_nil
      end
    end

    context 'when no data exists' do
      let(:timeframe) { Timeframe.new('2024-05') }

      it 'returns nil' do
        expect(call).to be_nil
      end
    end

    context 'with heatpump_power sensor' do
      let(:sensor) { Sensor::Registry[:heatpump_power] }

      before do
        stub_feature(:heatpump)
        travel_to Date.new(2025, 10, 28) # Set date after all test data

        create_summary(
          date: Date.new(2025, 10, 3),
          values: [[:heatpump_power, :sum, 12_000]],
        )
        create_summary(
          date: Date.new(2025, 10, 10),
          values: [[:heatpump_power, :sum, 18_000]],
        )
        create_summary(
          date: Date.new(2025, 10, 25),
          values: [[:heatpump_power, :sum, 9_000]],
        )
      end

      context 'when finding maximum' do
        let(:aggregation) { :max }

        it 'returns the day with highest heatpump power' do
          expect(call).to eq({ date: Date.new(2025, 10, 10), value: 18_000 })
        end
      end

      context 'when finding minimum' do
        let(:aggregation) { :min }

        it 'returns the day with lowest heatpump power' do
          expect(call).to eq({ date: Date.new(2025, 10, 25), value: 9_000 })
        end
      end
    end

    context 'with yearly timeframe' do
      let(:timeframe) { Timeframe.new('2025') }
      let(:aggregation) { :max }

      before do
        create_summary(
          date: Date.new(2025, 3, 15),
          values: [[:inverter_power, :sum, 30_000]],
        )
        create_summary(
          date: Date.new(2025, 6, 20),
          values: [[:inverter_power, :sum, 45_000]],
        )
        create_summary(
          date: Date.new(2025, 9, 10),
          values: [[:inverter_power, :sum, 20_000]],
        )
      end

      it 'searches across the entire year and returns the maximum day' do
        expect(call).to eq({ date: Date.new(2025, 6, 20), value: 45_000 })
      end
    end

    context 'with week timeframe' do
      let(:timeframe) { Timeframe.new('2025-W42') }
      let(:aggregation) { :max }

      before do
        # Week 42 in 2025 starts on October 13
        create_summary(
          date: Date.new(2025, 10, 13),
          values: [[:inverter_power, :sum, 12_000]],
        )
        create_summary(
          date: Date.new(2025, 10, 14),
          values: [[:inverter_power, :sum, 20_000]],
        )
        create_summary(
          date: Date.new(2025, 10, 15),
          values: [[:inverter_power, :sum, 18_000]],
        )
      end

      it 'searches within the week and returns the maximum day' do
        expect(call).to eq({ date: Date.new(2025, 10, 14), value: 20_000 })
      end
    end

    context 'with financial sensor (grid_revenue)' do
      let(:sensor) { Sensor::Registry[:grid_revenue] }
      let(:aggregation) { :max }

      before do
        # Grid revenue is sql-calculated from grid_export_power
        create_summary(
          date: Date.new(2025, 10, 5),
          values: [[:grid_export_power, :sum, 20_000]], # 20 kWh * 0.0832 = 1.664 EUR
        )
        create_summary(
          date: Date.new(2025, 10, 12),
          values: [[:grid_export_power, :sum, 35_000]], # 35 kWh * 0.0832 = 2.912 EUR
        )
        create_summary(
          date: Date.new(2025, 10, 20),
          values: [[:grid_export_power, :sum, 15_000]], # 15 kWh * 0.0832 = 1.248 EUR
        )
      end

      it 'returns the day with highest grid revenue' do
        expect(call).to eq({ date: Date.new(2025, 10, 12), value: 2.912 })
      end
    end

    context 'when handling edge case with equal values' do
      let(:aggregation) { :max }

      before do
        create_summary(
          date: Date.new(2025, 10, 5),
          values: [[:inverter_power, :sum, 20_000]],
        )
        create_summary(
          date: Date.new(2025, 10, 12),
          values: [[:inverter_power, :sum, 20_000]],
        )
        create_summary(
          date: Date.new(2025, 10, 20),
          values: [[:inverter_power, :sum, 20_000]],
        )
      end

      it 'returns the first occurrence (due to limit: 1)' do
        # With desc: true, it should return one of the maximum values
        expect(call[:value]).to eq(20_000)
        expect(call[:date]).to be_in(
          [
            Date.new(2025, 10, 5),
            Date.new(2025, 10, 12),
            Date.new(2025, 10, 20),
          ],
        )
      end
    end
  end
end
