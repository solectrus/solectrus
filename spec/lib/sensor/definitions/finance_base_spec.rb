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
      public :electricity_price, :feed_in_price, :to_kwh, :greatest, :coalesce
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
    describe '#electricity_price' do
      it 'returns correct price reference' do
        expect(instance.electricity_price).to eq('pb.eur_per_kwh')
      end
    end

    describe '#feed_in_price' do
      it 'returns correct price reference' do
        expect(instance.feed_in_price).to eq('pf.eur_per_kwh')
      end
    end

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
