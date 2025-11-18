describe Sensor::Definitions::HouseCostsGrid do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#sql_calculation' do
    subject(:sql_calculation) { instance.sql_calculation }

    it 'includes power field conversion to kWh' do
      expect(sql_calculation).to include('/ 1000.0')
    end

    it 'includes electricity price reference' do
      expect(sql_calculation).to include('pb_eur_per_kwh')
    end

    it 'includes power fields reference' do
      expect(sql_calculation).to include('house_power_grid_sum')
    end
  end
end
