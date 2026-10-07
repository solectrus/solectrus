describe Sensor::Units::Boolean do
  describe '.parse' do
    it 'keeps a boolean' do
      expect([true, false].map { described_class.parse(it) }).to eq([true, false])
    end

    it 'takes a positive number as true' do
      expect([1, 2, 0.5, 0, -1].map { described_class.parse(it) }).to eq([true, true, true, false, false])
    end

    it 'reads a word or a number as text, in any case' do
      expect(%w[true ON Yes 1 false Off no 0 -1].map { described_class.parse(it) }).to eq(
        [true, true, true, true, false, false, false, false, false],
      )
    end

    it 'gives nil for a value that is no boolean' do
      expect(['unavailable', '', nil].map { described_class.parse(it) }).to eq([nil, nil, nil])
    end
  end
end
