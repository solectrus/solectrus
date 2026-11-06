describe Sensor::Definitions::Dsl do
  # A sensor class body declares two things about its value: `range:` says what
  # the value may be, `calculate` says how it is derived. They used to be
  # enforced separately - the block ran unchecked, and every sensor whose
  # arithmetic can leave the range had to repeat the bound by hand. This is
  # where the two now meet.
  describe '.calculate' do
    def sensor_class(range: nil, &)
      block = Proc.new(&)

      Class.new(Sensor::Definitions::Base) do
        value(unit: :watt, range:)
        calculate(&block)
      end
    end

    it 'clamps a result below the declared range' do
      sensor = sensor_class(range: (0..)) { |base:, share:, **| base - share }.new

      expect(sensor.calculate(base: 100.0, share: 400.0)).to eq(0)
    end

    it 'clamps a result above the declared range' do
      sensor = sensor_class(range: (0..100)) { |value:, **| value }.new

      expect(sensor.calculate(value: 142.0)).to eq(100)
    end

    it 'leaves a result inside the range untouched' do
      sensor = sensor_class(range: (0..)) { |base:, share:, **| base - share }.new

      expect(sensor.calculate(base: 1_000.0, share: 400.0)).to eq(600.0)
    end

    it 'leaves a sensor without a declared range alone' do
      sensor = sensor_class { |base:, share:, **| base - share }.new

      expect(sensor.calculate(base: 100.0, share: 400.0)).to eq(-300.0)
    end

    # A calculate block returns nil to say "no value", and a few sensors return
    # something that is not a number at all. Neither has a range to fall into.
    it 'passes a nil result through' do
      sensor = sensor_class(range: (0..)) { |**| nil }.new

      expect(sensor.calculate(base: 1.0)).to be_nil
    end

    it 'passes a non-numeric result through' do
      sensor = sensor_class(range: (0..)) { |**| { x: -1 } }.new

      expect(sensor.calculate(base: 1.0)).to eq({ x: -1 })
    end

    # The block keeps method semantics, which is what the definitions rely on:
    # an early `return` leaves the calculation, and a missing dependency is an
    # error rather than a silent nil binding.
    it 'keeps an early return working' do
      sensor =
        sensor_class(range: (0..)) do |base:, **|
          return unless base

          base * 2
        end.new

      expect(sensor.calculate(base: nil)).to be_nil
    end

    it 'still raises when a required dependency is missing' do
      sensor = sensor_class(range: (0..)) { |base:, share:, **| base - share }.new

      expect { sensor.calculate(base: 100.0) }.to raise_error(
        ArgumentError,
        /missing keyword: :share/,
      )
    end

    it 'still reports the sensor as calculated' do
      expect(sensor_class { |**| 1 }.new).to be_calculated
    end
  end

  describe '.permitted' do
    it 'stores a static value' do
      sensor_class = Class.new(Sensor::Definitions::Base) do
        value unit: :watt
        permitted false
      end

      expect(sensor_class.permitted).to be(false)
      expect(sensor_class.new.permitted?).to be(false)
    end

    it 'stores a block that runs on the sensor' do
      sensor_class = Class.new(Sensor::Definitions::Base) do
        value unit: :watt
        permitted { unit == :watt }
      end

      expect(sensor_class.new.permitted?).to be(true)
    end

    it 'defaults to true' do
      sensor_class = Class.new(Sensor::Definitions::Base) { value unit: :watt }

      expect(sensor_class.permitted).to be(true)
    end
  end

  describe '.allowed_aggregations' do
    it 'stores the given aggregations, flattened' do
      sensor_class = Class.new(Sensor::Definitions::Base) do
        value unit: :watt
        allowed_aggregations %i[min max], :avg
      end

      expect(sensor_class.allowed_aggregations).to eq(%i[min max avg])
    end
  end

  describe '.summary_aggregations' do
    it 'stores the given aggregations, flattened' do
      sensor_class = Class.new(Sensor::Definitions::Base) do
        value unit: :watt
        summary_aggregations %i[sum], :max
      end

      expect(sensor_class.summary_aggregations).to eq(%i[sum max])
      expect(sensor_class.new.summary_aggregations).to eq(%i[sum max])
    end
  end

  describe '.depends_on with a condition' do
    def sensor_class(condition)
      Class.new(Sensor::Definitions::Base) do
        value unit: :watt
        depends_on :inverter_power, :house_power, if: condition
      end
    end

    it 'returns the dependencies when the condition holds' do
      expect(sensor_class(-> { true }).depends_on).to eq(%i[inverter_power house_power])
    end

    it 'returns no dependencies when the condition fails' do
      expect(sensor_class(-> { false }).new.dependencies).to eq([])
    end
  end
end
