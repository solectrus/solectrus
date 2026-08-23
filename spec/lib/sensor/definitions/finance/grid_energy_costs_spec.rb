describe Sensor::Definitions::GridEnergyCosts do # rubocop:disable RSpec/SpecFilePathFormat
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
      expect(sql_calculation).to include('grid_import_power_sum')
    end

    # The base fee is the other half of grid_costs, not part of this one.
    it 'carries no base fee' do
      expect(sql_calculation).not_to include('pb_base_fee_per_day')
      expect(instance).not_to be_carries_base_fee
    end
  end

  describe '#calculate_with_prices' do
    let(:prices) { { electricity: 0.30 } }

    it 'prices the imported energy' do
      value = instance.calculate_with_prices(grid_import_power: 1000, prices:)

      expect(value).to be_within(0.001).of(0.3)
    end

    it 'reports nothing without a reading' do
      value = instance.calculate_with_prices(grid_import_power: nil, prices:)

      expect(value).to be_nil
    end

    it 'reports nothing without a price' do
      value =
        instance.calculate_with_prices(grid_import_power: 1000, prices: {})

      expect(value).to be_nil
    end
  end
end
