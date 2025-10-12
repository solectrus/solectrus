describe Sensor::Definitions::GridRevenue do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#sql_calculation' do
    subject(:sql_calculation) { instance.sql_calculation }

    it 'includes power field conversion to kWh' do
      expect(sql_calculation).to include('/ 1000.0')
    end

    it 'includes feed-in price reference' do
      expect(sql_calculation).to include('pf_eur_per_kwh')
    end

    it 'includes grid export power reference' do
      expect(sql_calculation).to include('grid_export_power_sum')
    end
  end
end
