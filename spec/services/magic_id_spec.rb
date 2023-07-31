describe MagicId do
  subject(:magic_id) { described_class.new }

  let(:number) { Random.rand(1..Time.current.to_i) }

  describe '#encode' do
    subject(:encoded) { magic_id.encode(number) }

    it 'returns a short string' do
      expect(encoded).to be_a(String)
      expect(encoded.length).to eq(43)
    end

    it 'returns a different string each time' do
      first_encoded = magic_id.encode(number)
      second_encoded = magic_id.encode(number)
      expect(first_encoded).not_to eq(second_encoded)
    end

    it 'accepts integers only' do
      expect { magic_id.encode('invalid') }.to raise_error(ArgumentError)
    end
  end
end
