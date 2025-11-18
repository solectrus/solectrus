describe Sensor::Definitions::Savings do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#calculate' do
    subject(:calculation) { instance.calculate(**params) }

    context 'when all dependencies are given' do
      let(:params) { { solar_price: 30, traditional_costs: 100 } }

      it 'calculates the correct savings' do
        expect(calculation).to eq(70)
      end
    end

    context 'when solar_price is missing' do
      let(:params) { { traditional_costs: 100 } }

      it 'raises an error' do
        expect { calculation }.to raise_error(ArgumentError)
      end
    end

    context 'when traditional_costs are missing' do
      let(:params) { { solar_price: 30 } }

      it 'raises an error' do
        expect { calculation }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#sql_calculation' do
    it 'expands nested SQL calculations' do
      sql = instance.sql_calculation
      expect(sql).to include('grid_import_power_sum')
      expect(sql).to include('grid_export_power_sum')
      expect(sql).to include('house_power_sum')
      expect(sql).to include('heatpump_power_sum')
      expect(sql).to include('wallbox_power_sum')
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
