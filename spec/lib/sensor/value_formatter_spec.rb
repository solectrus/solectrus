describe Sensor::ValueFormatter do
  around { |example| I18n.with_locale(:de) { example.run } }

  describe '#to_h' do
    subject(:to_h) { described_class.new(value, unit:).to_h }

    context 'with kW value' do
      let(:value) { 2500 }
      let(:unit) { :watt }

      it 'returns a hash with all required keys' do
        expect(to_h).to be_a(Hash)
        expect(to_h.keys).to contain_exactly(:value, :integer, :decimal, :unit)
      end

      it 'splits into integer and decimal parts' do
        expect(to_h[:integer]).to eq('2')
        expect(to_h[:decimal]).to eq(',5')
        expect(to_h[:unit]).to eq('kW')
      end
    end

    context 'with W value (no decimals)' do
      let(:value) { 500 }
      let(:unit) { :watt }

      it 'handles values without decimals' do
        expect(to_h[:integer]).to eq('500')
        expect(to_h[:decimal]).to be_nil
        expect(to_h[:unit]).to eq('W')
      end
    end
  end

  describe 'unit type handling' do
    describe 'watt units (automatic scaling)' do
      context 'with power context (default for watt)' do
        subject(:result) { described_class.new(value, unit: :watt).to_h }

        context 'with 500 W' do
          let(:value) { 500 }

          it { expect(result[:value]).to eq('500') }
          it { expect(result[:unit]).to eq('W') }
        end

        context 'with 2500 W (2.5 kW)' do
          let(:value) { 2500 }

          it { expect(result[:value]).to eq('2,5') }
          it { expect(result[:unit]).to eq('kW') }
        end

        context 'with 2.5 MW' do
          let(:value) { 2_500_000 }

          it { expect(result[:value]).to eq('2,5') }
          it { expect(result[:unit]).to eq('MW') }
        end

        context 'with negative value' do
          let(:value) { -1500 }

          it { expect(result[:value]).to eq('-1,5') }
          it { expect(result[:unit]).to eq('kW') }
        end

        context 'with zero value' do
          let(:value) { 0 }

          it { expect(result[:value]).to eq('0') }
          it { expect(result[:unit]).to eq('W') }
        end
      end

      context 'with energy context' do
        subject(:result) do
          described_class.new(value, unit: :watt, context: :energy).to_h
        end

        context 'with 500 Wh' do
          let(:value) { 500 }

          it { expect(result[:value]).to eq('500') }
          it { expect(result[:unit]).to eq('Wh') }
        end

        context 'with 2.5 kWh' do
          let(:value) { 2500 }

          it { expect(result[:value]).to eq('2,5') }
          it { expect(result[:unit]).to eq('kWh') }
        end

        context 'with 2.5 MWh' do
          let(:value) { 2_500_000 }

          it { expect(result[:value]).to eq('2,5') }
          it { expect(result[:unit]).to eq('MWh') }
        end

        context 'with zero value' do
          let(:value) { 0 }

          it { expect(result[:value]).to eq('0') }
          it { expect(result[:unit]).to eq('Wh') }
        end

        context 'with zero value and kilo scaling' do
          subject(:result) do
            described_class.new(
              value,
              unit: :watt,
              context: :energy,
              scaling: :kilo,
            ).to_h
          end

          let(:value) { 0 }

          it { expect(result[:value]).to eq('0') }
          it { expect(result[:unit]).to eq('kWh') }
        end

        context 'with very small value (< 0.05 after scaling)' do
          subject(:result) do
            described_class.new(
              value,
              unit: :watt,
              context: :energy,
              scaling: :kilo,
            ).to_h
          end

          let(:value) { 10 } # 0.01 kWh after scaling

          it 'displays as 0 without decimals' do
            expect(result[:value]).to eq('0')
            expect(result[:unit]).to eq('kWh')
          end
        end

        describe 'large energy values precision' do
          subject(:result) do
            described_class.new(value, unit: :watt, context: :energy).to_h
          end

          context 'with large kWh value (958.3 kWh)' do
            let(:value) { 958_300 }

            it { expect(result[:value]).to eq('958') }
            it { expect(result[:unit]).to eq('kWh') }
          end

          context 'with 100 kWh boundary values' do
            context 'when below threshold (99.9 kWh)' do
              let(:value) { 99_900 }

              it { expect(result[:value]).to eq('99,9') }
            end

            context 'when at threshold (100 kWh)' do
              let(:value) { 100_000 }

              it { expect(result[:value]).to eq('100') }
            end
          end
        end
      end
    end

    describe 'gram units (automatic scaling)' do
      subject(:result) { described_class.new(value, unit: :gram).to_h }

      context 'with 500 g' do
        let(:value) { 500 }

        it { expect(result[:value]).to eq('500') }
        it { expect(result[:unit]).to eq('g') }
      end

      context 'with 1.5 kg (1500 g)' do
        let(:value) { 1500 }

        it { expect(result[:value]).to eq('2') }
        it { expect(result[:unit]).to eq('kg') }
      end

      context 'with 2.5 t (2,500,000 g)' do
        let(:value) { 2_500_000 }

        it { expect(result[:value]).to eq('2,5') }
        it { expect(result[:unit]).to eq('t') }
      end
    end

    describe 'simple units (no scaling)' do
      subject(:result) { described_class.new(value, unit:).to_h }

      context 'with celsius values' do
        let(:unit) { :celsius }
        let(:value) { 42.7 }

        it { expect(result[:value]).to eq('42,7') }
        it { expect(result[:unit]).to eq('°C') }
      end

      context 'with percent values' do
        let(:unit) { :percent }
        let(:value) { 85.3 }

        it { expect(result[:value]).to eq('85') }
        it { expect(result[:unit]).to eq('%') }
      end

      context 'with euro values' do
        let(:unit) { :euro }

        context 'when large amounts (>= 10 €)' do
          let(:value) { 123.45 }

          it { expect(result[:value]).to eq('123') }
          it { expect(result[:unit]).to eq('€') }
        end

        context 'when small amounts (< 10 €)' do
          let(:value) { 2.50 }

          it { expect(result[:value]).to eq('2,50') }
          it { expect(result[:unit]).to eq('€') }
        end
      end

      context 'with euro per kWh values' do
        let(:unit) { :euro_per_kwh }
        let(:value) { 0.30123 }

        it { expect(result[:value]).to eq('0,3012') }
        it { expect(result[:unit]).to eq('€/kWh') }
      end

      context 'with unitless values' do
        let(:unit) { :unitless }
        let(:value) { 3.2 }

        it { expect(result[:value]).to eq('3,20') }
        it { expect(result[:unit]).to be_nil }
      end
    end

    describe 'special units (no formatting)' do
      subject(:result) { described_class.new(value, unit:).to_h }

      context 'with string values' do
        let(:unit) { :string }
        let(:value) { 'CHARGING' }

        it { expect(result[:value]).to eq('CHARGING') }
        it { expect(result[:unit]).to be_nil }
      end

      context 'with boolean values' do
        let(:unit) { :boolean }

        context 'when true' do
          let(:value) { true }

          it { expect(result[:value]).to eq(I18n.t('general.yes')) }
          it { expect(result[:unit]).to be_nil }
        end

        context 'when false' do
          let(:value) { false }

          it { expect(result[:value]).to eq(I18n.t('general.no')) }
          it { expect(result[:unit]).to be_nil }
        end
      end
    end
  end

  describe 'precision handling' do
    describe 'unit-specific default precisions' do
      it 'uses precision 1 for celsius' do
        formatter = described_class.new(23.456, unit: :celsius)
        result = formatter.to_h

        expect(result[:value]).to eq('23,5')
      end

      it 'uses precision 0 for watt (W) and 1 for scaled units (kW/MW)' do
        formatter_w = described_class.new(567, unit: :watt)
        result_w = formatter_w.to_h
        expect(result_w[:value]).to eq('567')

        formatter_kw = described_class.new(1234.567, unit: :watt)
        result_kw = formatter_kw.to_h
        expect(result_kw[:value]).to eq('1,2')
      end

      it 'uses precision 0 for gram (g), precision 1 for kg and tonnes (t)' do
        formatter_g = described_class.new(567, unit: :gram)
        result_g = formatter_g.to_h
        expect(result_g[:value]).to eq('567')

        formatter_kg = described_class.new(1234.567, unit: :gram)
        result_kg = formatter_kg.to_h
        expect(result_kg[:value]).to eq('1')

        formatter_t = described_class.new(2_500_000, unit: :gram)
        result_t = formatter_t.to_h
        expect(result_t[:value]).to eq('2,5')
      end

      it 'uses dynamic precision for euro (large amounts: 0, small amounts: 2)' do
        # Large amounts (>= 10) use precision 0
        formatter_large = described_class.new(123.456789, unit: :euro)
        result_large = formatter_large.to_h
        expect(result_large[:value]).to eq('123')

        # Small amounts (< 10) use precision 2
        formatter_small = described_class.new(1.456789, unit: :euro)
        result_small = formatter_small.to_h
        expect(result_small[:value]).to eq('1,46')
      end

      it 'uses precision 4 for euro_per_kwh' do
        formatter = described_class.new(0.123456789, unit: :euro_per_kwh)
        result = formatter.to_h

        expect(result[:value]).to eq('0,1235')
      end

      it 'uses default precision 0 for percent' do
        formatter = described_class.new(85.456789, unit: :percent)
        result = formatter.to_h

        expect(result[:value]).to eq('85')
      end
    end

    describe 'explicit precision override' do
      it 'uses specified precision when provided' do
        formatter = described_class.new(2500.123, unit: :watt, precision: 2)
        result = formatter.to_h

        expect(result[:value]).to eq('2,50')
      end

      it 'falls back to scale-specific default when precision is nil' do
        formatter = described_class.new(2500.123, unit: :watt)
        result = formatter.to_h

        expect(result[:value]).to eq('2,5')
      end
    end

    describe 'euro formatting with size-based precision' do
      it 'formats large euro amounts without decimals' do
        formatter = described_class.new(1234.56, unit: :euro)
        result = formatter.to_h

        expect(result[:value]).to eq('1.235')
        expect(result[:unit]).to eq('€')
      end

      it 'formats small euro amounts with decimals' do
        formatter = described_class.new(5.99, unit: :euro)
        result = formatter.to_h

        expect(result[:value]).to eq('5,99')
        expect(result[:unit]).to eq('€')
      end

      it 'handles euro boundary value correctly' do
        formatter = described_class.new(10.00, unit: :euro)
        result = formatter.to_h

        expect(result[:value]).to eq('10')
        expect(result[:unit]).to eq('€')
      end
    end
  end

  describe 'context handling' do
    it 'auto-detects power context for watt sensors' do
      formatter = described_class.new(2500, unit: :watt, context: :auto)
      result = formatter.to_h

      expect(result[:unit]).to eq('kW')
    end

    it 'preserves explicit energy context' do
      formatter = described_class.new(2500, unit: :watt, context: :energy)
      result = formatter.to_h

      expect(result[:unit]).to eq('kWh')
    end

    it 'handles non-watt sensors with auto context' do
      formatter = described_class.new(42, unit: :celsius, context: :auto)
      result = formatter.to_h

      expect(result[:unit]).to eq('°C')
    end
  end

  describe 'edge cases and error handling' do
    describe 'nil and empty values' do
      it 'handles nil values gracefully' do
        formatter = described_class.new(nil, unit: :string)
        result = formatter.to_h

        expect(result[:value]).to eq('')
        expect(result[:unit]).to be_nil
      end

      it 'handles complex value types' do
        formatter = described_class.new({ status: 'ok' }, unit: :string)
        result = formatter.to_h

        expect(result[:value]).to be_a(String)
        expect(result[:unit]).to be_nil
      end
    end

    describe 'boundary conditions' do
      it 'handles threshold boundaries correctly' do
        test_cases = [
          { value: 999, expected_unit: 'W' },
          { value: 1000, expected_unit: 'kW' },
          { value: 999_999, expected_unit: 'kW' },
          { value: 1_000_000, expected_unit: 'MW' },
        ]

        test_cases.each do |test_case|
          formatter = described_class.new(test_case[:value], unit: :watt)
          result = formatter.to_h

          expect(result[:unit]).to eq(test_case[:expected_unit])
        end
      end

      it 'handles very small decimal values' do
        formatter = described_class.new(0.0001234, unit: :euro_per_kwh)
        result = formatter.to_h

        expect(result[:value]).to match(/0,0001/)
        expect(result[:unit]).to eq('€/kWh')
      end

      it 'handles floating point precision edge cases' do
        formatter = described_class.new(2999.9999, unit: :watt)
        result = formatter.to_h

        expect(result[:value]).to eq('3,0')
        expect(result[:unit]).to eq('kW')
      end

      it 'handles very large values' do
        formatter =
          described_class.new(10_000_000, unit: :watt, context: :power)
        result = formatter.to_h

        expect(result[:value]).to eq('10,0')
        expect(result[:unit]).to eq('MW')
      end
    end
  end
end
