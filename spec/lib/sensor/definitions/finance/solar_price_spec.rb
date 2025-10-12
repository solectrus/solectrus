describe Sensor::Definitions::SolarPrice do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#calculate' do
    subject(:calculation) { instance.calculate(**params) }

    context 'when all dependencies are given' do
      let(:params) { { grid_costs: 100, grid_revenue: 70 } }

      it 'calculates the correct solar price' do
        expect(calculation).to eq(30)
      end
    end

    context 'when grid_costs are missing' do
      let(:params) { { grid_revenue: 70 } }

      it 'raises an error' do
        expect { calculation }.to raise_error(ArgumentError)
      end
    end

    context 'when grid_revenue is missing' do
      let(:params) { { grid_costs: 100 } }

      it 'raises an error' do
        expect { calculation }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#sql_calculation' do
    it 'expands to grid_costs and grid_revenue calculations' do
      sql = instance.sql_calculation
      expect(sql).to include('grid_import_power_sum')
      expect(sql).to include('grid_export_power_sum')
    end
  end

  describe '#required_prices' do
    it 'requires both electricity and feed_in prices' do
      expect(instance.required_prices).to contain_exactly(
        :electricity,
        :feed_in,
      )
    end
  end
end
