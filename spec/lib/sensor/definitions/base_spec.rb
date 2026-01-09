describe Sensor::Definitions::Base do
  # Test concrete implementation class
  let(:test_class) do
    Class.new(described_class) do
      def unit
        :watt
      end
    end
  end

  let(:invalid_unit_class) do
    Class.new(described_class) do
      def unit
        :invalid_unit
      end
    end
  end

  let(:calculated_sensor_class) do
    Class.new(described_class) do
      def unit
        :percent
      end

      def calculate(_data)
        50.0
      end
    end
  end

  describe '#initialize' do
    it 'validates unit on initialization' do
      expect { test_class.new }.not_to raise_error
    end

    it 'raises error for invalid unit' do
      expect { invalid_unit_class.new }.to raise_error(
        ArgumentError,
        /Invalid unit :invalid_unit.*Must be one of/,
      )
    end
  end

  describe '#name' do
    it 'derives name from class name' do
      stub_const('Sensor::Definitions::TestSensor', test_class)
      sensor = test_class.new
      expect(sensor.name).to eq(:test_sensor)
    end
  end

  describe '#display_name' do
    let(:sensor) { test_class.new }

    before do
      stub_const('Sensor::Definitions::TestSensor', test_class)
      allow(I18n).to receive(:t).and_return('Test sensor')
    end

    it 'uses I18n for short format' do
      sensor.display_name(:short)
      expect(I18n).to have_received(:t).with(
        'sensors.test_sensor_short',
        default: 'Test sensor',
      )
    end

    it 'uses I18n for long format' do
      sensor.display_name(:long)
      expect(I18n).to have_received(:t).with(
        'sensors.test_sensor',
        default: 'test_sensor',
      )
    end

    it 'defaults to long format' do
      sensor.display_name
      expect(I18n).to have_received(:t).with(
        'sensors.test_sensor',
        default: 'test_sensor',
      )
    end
  end

  describe '#unit' do
    it 'raises NotImplementedError in base class' do
      expect { described_class.new.unit }.to raise_error(NotImplementedError)
    end
  end

  describe 'default values' do
    let(:sensor) { test_class.new }

    it 'has nil color_hex' do
      expect(sensor.color_hex).to be_nil
    end

    it 'has nil color_bg' do
      expect(sensor.color_bg).to be_nil
    end

    it 'has nil color_text' do
      expect(sensor.color_text).to be_nil
    end

    it 'has nil icon' do
      expect(sensor.icon).to be_nil
    end

    it 'has :other category' do
      expect(sensor.category).to eq(:other)
    end

    it 'is not chart enabled by default' do
      expect(sensor.chart_enabled?).to be(false)
    end

    it 'is not top10 enabled by default' do
      expect(sensor.top10_enabled?).to be(false)
    end

    it 'is top10 permitted by default' do
      expect(sensor.top10_permitted?).to be(true)
    end

    it 'is not nameable by default' do
      expect(sensor.nameable?).to be(false)
    end

    it 'has empty dependencies' do
      expect(sensor.dependencies).to eq([])
    end

    it 'has empty summary aggregations' do
      expect(sensor.summary_aggregations).to eq([])
    end

    it 'is permitted by default' do
      expect(sensor.permitted?).to be(true)
    end
  end

  describe '#calculated?' do
    it 'returns false for non-calculated sensors' do
      sensor = test_class.new
      expect(sensor.calculated?).to be(false)
    end

    it 'returns true for calculated sensors' do
      sensor = calculated_sensor_class.new
      expect(sensor.calculated?).to be(true)
    end
  end

  describe '#store_in_summary?' do
    it 'returns false when no summary aggregations' do
      sensor = test_class.new
      expect(sensor.store_in_summary?).to be(false)
    end

    it 'returns true when summary aggregations exist' do
      sensor = test_class.new
      allow(sensor).to receive(:summary_aggregations).and_return([:sum])
      expect(sensor.store_in_summary?).to be(true)
    end
  end

  describe 'valid units' do
    %i[watt celsius percent unitless boolean string].each do |valid_unit|
      it "accepts #{valid_unit} as valid unit" do
        unit_class =
          Class.new(described_class) { define_method(:unit) { valid_unit } }

        expect { unit_class.new }.not_to raise_error
      end
    end
  end

  describe '#value_range' do
    it 'returns nil by default' do
      sensor = test_class.new
      expect(sensor.value_range).to be_nil
    end
  end

  describe '#clamp_value' do
    context 'when no value_range is defined' do
      let(:sensor) { test_class.new }

      it 'returns original value for numeric values' do
        expect(sensor.clamp_value(42.5)).to eq(42.5)
        expect(sensor.clamp_value(-10)).to eq(-10)
      end

      it 'returns original value for non-numeric values' do
        expect(sensor.clamp_value('text')).to eq('text')
        expect(sensor.clamp_value(nil)).to be_nil
      end
    end

    context 'when value_range is defined' do
      let(:range_sensor_class) do
        Class.new(described_class) do
          def unit
            :percent
          end

          def value_range
            0..100
          end
        end
      end

      let(:sensor) { range_sensor_class.new }

      it 'returns original value when within range' do
        expect(sensor.clamp_value(50)).to eq(50)
        expect(sensor.clamp_value(0)).to eq(0)
        expect(sensor.clamp_value(100)).to eq(100)
      end

      it 'clamps values below minimum' do
        expect(sensor.clamp_value(-10)).to eq(0)
        expect(sensor.clamp_value(-0.1)).to eq(0)
      end

      it 'clamps values above maximum' do
        expect(sensor.clamp_value(150)).to eq(100)
        expect(sensor.clamp_value(100.1)).to eq(100)
      end

      it 'returns original value for non-numeric values' do
        expect(sensor.clamp_value('text')).to eq('text')
        expect(sensor.clamp_value(nil)).to be_nil
      end
    end

    context 'with endless range' do
      let(:endless_range_sensor_class) do
        Class.new(described_class) do
          def unit
            :watt
          end

          def value_range
            0.. # From 0 to infinity
          end
        end
      end

      let(:sensor) { endless_range_sensor_class.new }

      it 'allows positive values' do
        expect(sensor.clamp_value(42.5)).to eq(42.5)
        expect(sensor.clamp_value(1000)).to eq(1000)
      end

      it 'clamps negative values to minimum' do
        expect(sensor.clamp_value(-10)).to eq(0)
        expect(sensor.clamp_value(-0.1)).to eq(0)
      end
    end
  end
end
