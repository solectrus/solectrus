describe Sensor::Definitions::HouseCostsPv do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#sql_calculation' do
    subject(:sql_calculation) { instance.sql_calculation }

    it 'includes power fields reference' do
      expect(sql_calculation).to include('house_power_grid_sum')
      expect(sql_calculation).to include('house_power_sum')
    end

    it 'includes feed-in price reference' do
      expect(sql_calculation).to include('pf_eur_per_kwh')
    end
  end

  describe 'inheritance' do
    it 'inherits from FinanceBase' do
      expect(instance).to be_a(Sensor::Definitions::FinanceBase)
    end
  end
end
