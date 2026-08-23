describe Sensor::Definitions::HouseCostsGrid do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#sql_calculation' do
    subject(:sql_calculation) { instance.sql_calculation }

    it 'includes power field conversion to kWh' do
      expect(sql_calculation).to include('/ 1000.0')
    end

    it 'includes electricity price reference' do
      expect(sql_calculation).to include('pb_money_per_kwh')
    end

    it 'includes power fields reference' do
      expect(sql_calculation).to include('house_power_grid_sum')
    end
  end

  describe '#dependencies' do
    it 'reads the grid share of the house alone' do
      expect(instance.dependencies).to eq([:house_power_grid])
      expect(instance.static_dependencies).to eq([:house_power_grid])
    end
  end

  # The house carries the base fee, but only where grid_costs has one as well:
  # otherwise the per-consumer costs no longer add up to grid_costs.
  describe '#carries_base_fee?' do
    before do
      allow(Sensor::Config).to receive(:exists?).and_call_original
      allow(Sensor::Config).to receive(:exists?).with(:grid_base_fee).and_return(
        grid_base_fee,
      )
    end

    context 'with a grid meter' do
      let(:grid_base_fee) { true }

      it { expect(instance).to be_carries_base_fee }
    end

    context 'without a grid meter' do
      let(:grid_base_fee) { false }

      it { expect(instance).not_to be_carries_base_fee }

      it 'bills no fee in SQL' do
        expect(instance.sql_calculation).not_to include('pb_base_fee_per_day')
      end
    end
  end
end
