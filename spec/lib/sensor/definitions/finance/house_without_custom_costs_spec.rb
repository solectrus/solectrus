describe Sensor::Definitions::HouseWithoutCustomCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    subject { sensor.calculate(**params) }

    let(:base) do
      { house_power: 1000.0, house_power_without_custom: 400.0, house_costs: 5.0 }
    end

    context 'without a base fee' do
      let(:params) { base }

      it { is_expected.to be_within(0.001).of(2.0) }
    end

    # No custom consumer carries a share of the base fee, so the rest of the
    # house keeps it in full: 0.4 * (5.0 - 1.0) + 1.0
    context 'with a base fee' do
      let(:params) { base.merge(grid_base_fee: 1.0) }

      it { is_expected.to be_within(0.001).of(2.6) }
    end

    context 'with house_power zero' do
      let(:params) { base.merge(house_power: 0) }

      it { is_expected.to be_nil }
    end
  end

  describe '#dependencies' do
    it 'reads the base fee where the house carries it' do
      expect(sensor.dependencies).to include(:grid_base_fee)
    end

    # The fee only corrects the split, so a missing grid meter must not prune
    # the sensor.
    it 'does not exist or fall by the base fee' do
      expect(sensor.static_dependencies).to eq(
        %i[house_power house_power_without_custom house_costs],
      )
    end
  end
end
