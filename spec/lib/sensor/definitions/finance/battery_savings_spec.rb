describe Sensor::Definitions::BatterySavings do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  let(:prices) { { electricity: 0.3, feed_in: 0.08 } }

  describe '#calculate_with_prices' do
    subject { sensor.calculate_with_prices(prices:, **params) }

    context 'without grid shares' do
      let(:params) do
        { battery_discharging_power: 2000, battery_charging_power: 2500 }
      end

      it { is_expected.to eq(((2000 * 0.3) - (2500 * 0.08)) / 1000.0) }
    end

    context 'with grid shares on both sides' do
      let(:params) do
        {
          battery_discharging_power: 2000,
          battery_discharging_power_grid: 500,
          battery_charging_power: 2500,
          battery_charging_power_grid: 500,
        }
      end

      it 'counts only the PV share of both directions' do
        is_expected.to eq(((1500 * 0.3) - (2000 * 0.08)) / 1000.0)
      end
    end

    context 'when everything passed through the battery came from the grid' do
      let(:params) do
        {
          battery_discharging_power: 2000,
          battery_discharging_power_grid: 2000,
          battery_charging_power: 2000,
          battery_charging_power_grid: 2000,
        }
      end

      it 'saves nothing' do
        is_expected.to eq(0)
      end
    end

    context 'when a grid share exceeds its total by a rounding error' do
      let(:params) do
        {
          battery_discharging_power: 1000,
          battery_discharging_power_grid: 1001,
          battery_charging_power: 0,
          battery_charging_power_grid: 0,
        }
      end

      it 'does not turn the share negative' do
        is_expected.to eq(0)
      end
    end

    context 'without a feed-in price' do
      let(:prices) { { electricity: 0.3 } }
      let(:params) do
        { battery_discharging_power: 2000, battery_charging_power: 2500 }
      end

      it { is_expected.to be_nil }
    end
  end

  describe '#dependencies' do
    subject { sensor.dependencies }

    context 'when the grid shares are configured' do
      before { allow(Sensor::Config).to receive(:exists?).and_return(true) }

      it do
        is_expected.to eq(
          %i[
            battery_discharging_power
            battery_charging_power
            battery_discharging_power_grid
            battery_charging_power_grid
          ],
        )
      end

      it 'subtracts them in SQL' do
        expect(sensor.sql_calculation).to include(
          'GREATEST(COALESCE(battery_discharging_power_sum, 0) - COALESCE(battery_discharging_power_grid_sum, 0), 0)',
        )
      end
    end

    context 'when the grid shares are not configured' do
      before { allow(Sensor::Config).to receive(:exists?).and_return(false) }

      it do
        is_expected.to eq(
          %i[battery_discharging_power battery_charging_power],
        )
      end

      it 'does not reference the missing columns in SQL' do
        expect(sensor.sql_calculation).not_to include('_grid_sum')
      end
    end
  end

  # The sensor must survive on the base sensors alone, otherwise systems without
  # the Power Splitter would lose it entirely.
  describe '#static_dependencies' do
    subject { sensor.static_dependencies }

    it do
      is_expected.to eq(%i[battery_discharging_power battery_charging_power])
    end
  end
end
