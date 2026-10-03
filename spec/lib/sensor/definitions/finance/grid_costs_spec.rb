describe Sensor::Definitions::GridCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  # grid_costs = grid_energy_costs + grid_base_fee, on both backends.
  describe '#dependencies' do
    it 'names both halves' do
      expect(instance.dependencies).to eq(%i[grid_energy_costs grid_base_fee])
    end
  end

  describe '#sql_calculation' do
    it 'sums the SQL of both halves' do
      expect(instance.sql_calculation).to eq(
        "(#{Sensor::Registry[:grid_energy_costs].sql_calculation}) + " \
          "(#{Sensor::Registry[:grid_base_fee].sql_calculation})",
      )
    end
  end

  describe '#calculate' do
    it 'sums both halves' do
      value = instance.calculate(grid_energy_costs: 0.3, grid_base_fee: 2.0)

      expect(value).to be_within(0.001).of(2.3)
    end

    # The fee buys the grid connection and falls due whether the meter reports
    # or not, so a missing reading cancels the energy costs alone.
    it 'bills the fee without energy costs' do
      value = instance.calculate(grid_energy_costs: nil, grid_base_fee: 2.0)

      expect(value).to eq(2.0)
    end

    # Nothing measured and nothing to bill, so the gap stays a gap.
    it 'reports nothing where neither half has a value' do
      value = instance.calculate(grid_energy_costs: nil, grid_base_fee: nil)

      expect(value).to be_nil
    end
  end

  describe '#summary_meta_aggregations' do
    subject { instance.summary_meta_aggregations }

    it { is_expected.to eq(%i[sum min max]) }
  end
end
