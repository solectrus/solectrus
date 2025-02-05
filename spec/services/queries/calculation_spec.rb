describe Queries::Calculation do
  let(:valid_field) { :house_power }
  let(:valid_aggregation) { :sum }
  let(:valid_meta_aggregation) { :avg }

  describe '#initialize' do
    it 'creates an instance with valid parameters' do
      calc =
        described_class.new(
          valid_field,
          valid_aggregation,
          valid_meta_aggregation,
          100,
        )

      expect(calc.field).to eq(:house_power)
      expect(calc.aggregation).to eq(:sum)
      expect(calc.meta_aggregation).to eq(:avg)
      expect(calc.value).to eq(100)
    end

    it 'raises an error for an invalid field' do
      expect do
        described_class.new(
          :invalid_field,
          valid_aggregation,
          valid_meta_aggregation,
        )
      end.to raise_error(ArgumentError, /Field :invalid_field is invalid!/)
    end

    it 'raises an error for an invalid aggregation' do
      expect do
        described_class.new(
          valid_field,
          :invalid_aggregation,
          valid_meta_aggregation,
        )
      end.to raise_error(
        ArgumentError,
        /Aggregation :invalid_aggregation is invalid!/,
      )
    end

    it 'raises an error for an invalid meta aggregation' do
      expect do
        described_class.new(
          valid_field,
          valid_aggregation,
          :invalid_meta_aggregation,
        )
      end.to raise_error(
        ArgumentError,
        /Meta aggregation :invalid_meta_aggregation is invalid!/,
      )
    end
  end

  describe '#to_key' do
    it 'returns the correct key' do
      calc =
        described_class.new(
          valid_field,
          valid_aggregation,
          valid_meta_aggregation,
        )
      expect(calc.to_key).to eq(%i[house_power sum avg])
    end
  end

  describe '#base_key' do
    it 'returns the correct base key' do
      calc =
        described_class.new(
          valid_field,
          valid_aggregation,
          valid_meta_aggregation,
        )
      expect(calc.base_key).to eq(%i[house_power sum])
    end
  end

  describe '#with_value' do
    it 'returns a new instance with updated value' do
      calc =
        described_class.new(
          valid_field,
          valid_aggregation,
          valid_meta_aggregation,
          100,
        )
      new_calc = calc.with_value(200)

      expect(new_calc).to be_a(described_class)
      expect(new_calc.value).to eq(200)
      expect(new_calc.field).to eq(calc.field)
      expect(new_calc.aggregation).to eq(calc.aggregation)
      expect(new_calc.meta_aggregation).to eq(calc.meta_aggregation)
    end
  end
end
