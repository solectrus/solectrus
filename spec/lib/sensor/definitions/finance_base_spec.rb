describe Sensor::Definitions::FinanceBase do
  let(:test_class) do
    Class.new(described_class) do
      depends_on :test_field

      def required_prices
        [:test_price]
      end

      def sql_calculation
        'SUM(test_calculation)'
      end

      # Make protected methods public for testing
      public :to_kwh, :greatest, :coalesce
    end
  end

  let(:instance) { test_class.new }

  describe '#display_name' do
    context 'with unknown format' do
      let(:format) { :unknown }

      it 'raises ArgumentError' do
        expect { instance.display_name(format) }.to raise_error(
          ArgumentError,
          'Unknown display name format: unknown',
        )
      end
    end
  end

  # Only test type conversion behavior, not trivial boolean returns
  describe '#needs_price?' do
    it 'converts string to symbol for comparison' do
      expect(instance.needs_price?('test_price')).to be(true)
    end

    it 'returns false for unknown price type' do
      expect(instance.needs_price?(:unknown_price)).to be(false)
    end
  end

  # Test SQL helper methods
  describe 'SQL helper methods' do
    describe '#to_kwh' do
      it 'converts Wh expression to kWh' do
        expect(instance.to_kwh('sums.power_sum')).to eq(
          '(sums.power_sum) / 1000.0',
        )
      end
    end

    describe '#greatest' do
      it 'returns GREATEST SQL expression with default fallback' do
        expect(instance.greatest('test_expression')).to eq(
          'GREATEST(test_expression, 0)',
        )
      end

      it 'returns GREATEST SQL expression with custom fallback' do
        expect(instance.greatest('test_expression', 5)).to eq(
          'GREATEST(test_expression, 5)',
        )
      end
    end

    describe '#coalesce' do
      it 'returns COALESCE SQL expression with default fallback' do
        expect(instance.coalesce('test_expression')).to eq(
          'COALESCE(test_expression, 0)',
        )
      end

      it 'returns COALESCE SQL expression with custom fallback' do
        expect(instance.coalesce('test_expression', 'NULL')).to eq(
          'COALESCE(test_expression, NULL)',
        )
      end
    end
  end

  # One declaration, read by both backends: #with_base_fee_sql builds the SQL
  # term from it, #with_base_fee the InfluxDB one. Thus a sensor cannot bill the
  # fee in SQL and forget it in InfluxDB.
  describe 'base fee' do
    it 'is carried by no sensor unless it says so' do
      expect(instance).not_to be_carries_base_fee
      expect(instance.with_base_fee(1.0, 2)).to eq(1.0)
    end

    context 'with the fee on its own' do
      subject(:sensor) { Sensor::Registry[:grid_base_fee] }

      it 'declares it' do
        expect(sensor).to be_carries_base_fee
      end

      it 'reads the daily column in SQL' do
        expect(sensor.sql_calculation).to eq('COALESCE(pb_base_fee_per_day, 0)')
      end

      it 'is the fee alone' do
        expect(sensor.with_base_fee(nil, 2)).to eq(2)
      end
    end

    # The house carries the fee on top of its energy costs. A missing reading
    # cancels the energy costs but not the fee, in both backends alike.
    context 'with a consumer that carries the fee' do
      subject(:sensor) { Sensor::Registry[:house_costs_grid] }

      it 'declares it' do
        expect(sensor).to be_carries_base_fee
      end

      it 'adds the daily column in SQL, and keeps it where the energy is NULL' do
        energy = 'house_power_grid_sum * pb_money_per_kwh / 1000.0'

        expect(sensor.sql_calculation).to eq(
          "COALESCE(#{energy} + pb_base_fee_per_day, #{energy}, pb_base_fee_per_day)",
        )
      end

      it 'adds the whole fee to a value' do
        expect(sensor.with_base_fee(1.0, 2)).to eq(3.0)
      end

      it 'keeps the fee without a value' do
        expect(sensor.with_base_fee(nil, 2)).to eq(2)
      end

      it 'keeps a gap a gap without a fee' do
        expect(sensor.with_base_fee(nil, 0)).to be_nil
      end
    end

    # The fee does not grow with the consumption, so the other consumers carry
    # none of it.
    it 'is carried by no other consumer' do
      %i[heatpump_costs_grid wallbox_costs_grid].each do |name|
        sensor = Sensor::Registry[name]

        expect(sensor).not_to be_carries_base_fee
        expect(sensor.sql_calculation).not_to include('pb_base_fee_per_day')
        expect(sensor.with_base_fee(1.0, 2)).to eq(1.0)
      end
    end

    # A composed sensor inherits the fee from the sensors it splices, so it must
    # not declare one of its own.
    it 'is inherited by a composed sensor' do
      %i[grid_costs total_costs].each do |name|
        sensor = Sensor::Registry[name]

        expect(sensor).not_to be_carries_base_fee
        expect(sensor.sql_calculation).to include('pb_base_fee_per_day')
      end
    end
  end

  describe 'abstract methods' do
    let(:base_instance) { described_class.new }

    it 'raises NotImplementedError for required_prices' do
      expect { base_instance.required_prices }.to raise_error(
        NotImplementedError,
        'Subclass must implement #required_prices',
      )
    end

    it 'raises NotImplementedError for sql_calculation' do
      expect { base_instance.sql_calculation }.to raise_error(
        NotImplementedError,
        'Subclass must implement #sql_calculation',
      )
    end
  end
end
