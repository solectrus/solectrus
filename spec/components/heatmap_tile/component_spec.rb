describe HeatmapTile::Component, type: :component do
  subject(:component) { described_class.new(data:, sensor:, timeframe:) }

  let(:timeframe) { Timeframe.new('2025') }

  describe '#use_range_based_opacity?' do
    subject(:use_range_based_opacity?) do
      component.send(:use_range_based_opacity?) # rubocop:disable Style/Send
    end

    context 'when sensor uses sum aggregation' do
      let(:sensor) { Sensor::Registry[:inverter_power] }
      let(:data) { {} }

      it { is_expected.to be false }
    end

    context 'when sensor uses avg aggregation' do
      let(:sensor) { Sensor::Registry[:heatpump_cop] }
      let(:data) { {} }

      it { is_expected.to be true }
    end
  end

  describe '#standard_opacity' do
    subject(:opacity) do
      component.send(:standard_opacity, value) # rubocop:disable Style/Send
    end

    context 'with sum aggregation sensor (absolute opacity)' do
      let(:sensor) { Sensor::Registry[:inverter_power] }
      let(:data) do
        {
          1 => {
            1 => 1000,
            2 => 2000,
            3 => 3000,
          },
          2 => {
            1 => 4000,
            2 => 5000,
          },
        }
      end
      let(:value) { 2500 }

      it 'calculates opacity relative to max value' do
        # max_value = 5000
        # opacity = 2500 / 5000 = 0.5
        expect(opacity).to eq(0.5)
      end
    end

    context 'with avg aggregation sensor (range-based opacity)' do
      let(:sensor) { Sensor::Registry[:heatpump_cop] }
      let(:data) do
        {
          1 => {
            1 => 2.0,
            2 => 3.0,
            3 => 4.0,
            4 => 0,
          },
          2 => {
            1 => 2.5,
            2 => 4.5,
            3 => 0,
          },
        }
      end

      context 'with zero value (no heating)' do
        let(:value) { 0 }

        it 'returns zero opacity (invisible)' do
          expect(opacity).to eq(0)
        end
      end

      context 'with minimum non-zero value' do
        let(:value) { 2.0 }

        it 'returns minimum opacity (0.2)' do
          # Zeros are excluded from range calculation
          # min = 2.0, max = 4.5, range = 2.5
          # normalized = (2.0 - 2.0) / 2.5 = 0.0
          # opacity = 0.2 + (0.0 * 0.8) = 0.2
          expect(opacity).to eq(0.2)
        end
      end

      context 'with maximum value' do
        let(:value) { 4.5 }

        it 'returns maximum opacity (1.0)' do
          # normalized = (4.5 - 2.0) / 2.5 = 1.0
          # opacity = 0.2 + (1.0 * 0.8) = 1.0
          expect(opacity).to eq(1.0)
        end
      end

      context 'with middle value' do
        let(:value) { 3.25 }

        it 'returns interpolated opacity' do
          # normalized = (3.25 - 2.0) / 2.5 = 0.5
          # opacity = 0.2 + (0.5 * 0.8) = 0.6
          expect(opacity).to eq(0.6)
        end
      end
    end
  end

  describe '#min_value' do
    subject(:min_value) do
      component.send(:min_value) # rubocop:disable Style/Send
    end

    let(:sensor) { Sensor::Registry[:heatpump_cop] }
    let(:data) do
      {
        1 => {
          1 => 2.0,
          2 => 3.0,
          3 => 4.0,
          4 => 0,
        },
        2 => {
          1 => 2.5,
          2 => 4.5,
          3 => 0,
        },
      }
    end

    it 'returns the minimum non-zero value from all data' do
      # Zeros (no heating days) are excluded
      expect(min_value).to eq(2.0)
    end
  end

  describe '#max_value' do
    subject(:max_value) do
      component.send(:max_value) # rubocop:disable Style/Send
    end

    let(:sensor) { Sensor::Registry[:heatpump_cop] }
    let(:data) do
      {
        1 => {
          1 => 2.0,
          2 => 3.0,
          3 => 4.0,
          4 => 0,
        },
        2 => {
          1 => 2.5,
          2 => 4.5,
          3 => 0,
        },
      }
    end

    it 'returns the maximum value from all data' do
      # Zeros (no heating days) are excluded
      expect(max_value).to eq(4.5)
    end
  end
end
