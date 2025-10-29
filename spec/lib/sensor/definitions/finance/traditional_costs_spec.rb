describe Sensor::Definitions::TraditionalCosts do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#sql_calculation' do
    subject(:sql_calculation) { instance.sql_calculation }

    it 'includes power field conversion to kWh' do
      expect(sql_calculation).to include('/ 1000.0')
    end

    it 'includes electricity price reference' do
      expect(sql_calculation).to include('pb_eur_per_kwh')
    end

    context 'when all sensors are configured' do
      it 'includes all power fields' do
        expect(sql_calculation).to include('house_power_sum')
        expect(sql_calculation).to include('heatpump_power_sum')
        expect(sql_calculation).to include('wallbox_power_sum')
      end
    end

    context 'when heatpump_power is not configured' do
      before do
        allow(Sensor::Config).to receive(:configured?).and_call_original
        allow(Sensor::Config).to receive(:configured?).with(
          :heatpump_power,
        ).and_return(false)
      end

      it 'excludes heatpump_power_sum' do
        expect(sql_calculation).to include('house_power_sum')
        expect(sql_calculation).not_to include('heatpump_power_sum')
        expect(sql_calculation).to include('wallbox_power_sum')
      end
    end

    context 'when wallbox_power is not configured' do
      before do
        allow(Sensor::Config).to receive(:configured?).and_call_original
        allow(Sensor::Config).to receive(:configured?).with(
          :wallbox_power,
        ).and_return(false)
      end

      it 'excludes wallbox_power_sum' do
        expect(sql_calculation).to include('house_power_sum')
        expect(sql_calculation).to include('heatpump_power_sum')
        expect(sql_calculation).not_to include('wallbox_power_sum')
      end
    end

    context 'when only house_power is configured' do
      before do
        allow(Sensor::Config).to receive(:configured?).and_call_original
        allow(Sensor::Config).to receive(:configured?).with(
          :heatpump_power,
        ).and_return(false)
        allow(Sensor::Config).to receive(:configured?).with(
          :wallbox_power,
        ).and_return(false)
      end

      it 'only includes house_power_sum' do
        expect(sql_calculation).to include('house_power_sum')
        expect(sql_calculation).not_to include('heatpump_power_sum')
        expect(sql_calculation).not_to include('wallbox_power_sum')
        expect(sql_calculation).to eq(
          '(COALESCE(house_power_sum,0)) * pb_eur_per_kwh / 1000.0',
        )
      end
    end
  end

  describe '#calculate_with_prices' do
    let(:prices) { { electricity: 0.30 } }

    context 'when all parameters are provided' do
      it 'calculates correct costs' do
        result =
          instance.calculate_with_prices(
            house_power: 1000,
            heatpump_power: 500,
            wallbox_power: 300,
            prices:,
          )

        expect(result).to eq(0.54) # (1000 + 500 + 300) * 0.30 / 1000
      end
    end

    context 'when wallbox_power is not provided' do
      before do
        allow(Sensor::Config).to receive(:configured?).and_call_original
        allow(Sensor::Config).to receive(:configured?).with(
          :wallbox_power,
        ).and_return(false)
      end

      it 'calculates without wallbox_power' do
        result =
          instance.calculate_with_prices(
            house_power: 1000,
            heatpump_power: 500,
            prices:,
          )

        expect(result).to eq(0.45) # (1000 + 500) * 0.30 / 1000
      end
    end

    context 'when only house_power is provided' do
      before do
        allow(Sensor::Config).to receive(:configured?).and_call_original
        allow(Sensor::Config).to receive(:configured?).with(
          :heatpump_power,
        ).and_return(false)
        allow(Sensor::Config).to receive(:configured?).with(
          :wallbox_power,
        ).and_return(false)
      end

      it 'calculates with house_power only' do
        result = instance.calculate_with_prices(house_power: 1000, prices:)

        expect(result).to eq(0.30) # 1000 * 0.30 / 1000
      end
    end

    context 'when electricity price is missing' do
      let(:prices) { {} }

      it 'returns nil' do
        result = instance.calculate_with_prices(house_power: 1000, prices:)

        expect(result).to be_nil
      end
    end
  end
end
