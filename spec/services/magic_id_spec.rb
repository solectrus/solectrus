describe MagicId do
  subject(:magic_id) { described_class.new }

  let(:number) { Random.rand(1..Time.current.to_i) }
  let(:secret) { SecureRandom.alphanumeric(16) }

  describe '#encode' do
    subject(:encoded) { magic_id.encode(number, secret) }

    it 'returns a short string' do
      expect(encoded).to be_a(String)
      expect(encoded.length).to be_between(62, 76)
    end

    it 'returns a different string each time' do
      first_encoded = magic_id.encode(number, secret)
      second_encoded = magic_id.encode(number, secret)
      expect(first_encoded).not_to eq(second_encoded)
    end

    it 'accepts integers only' do
      expect { magic_id.encode('invalid', secret) }.to raise_error(
        ArgumentError,
      )
    end
  end
end
