describe Sensor::MeterReadings do
  subject(:values) { described_class.new(readings).call.map(&:last) }

  let(:start) { Time.zone.local(2026, 6, 10, 8) }

  def at(hours, value) = [start + hours.hours, value]

  context 'with a 0 of an offline car' do
    let(:readings) { [at(0, 1000), at(1, 0), at(2, 1010)] }

    it 'leaves it out' do
      expect(values).to eq([1000, 1010])
    end
  end

  context 'with a reading below the one before' do
    let(:readings) { [at(0, 1000), at(1, 12), at(2, 1010)] }

    it 'leaves it out' do
      expect(values).to eq([1000, 1010])
    end
  end

  # For example a new source that counts from another value
  context 'with a change that the next reading confirms' do
    let(:readings) { [at(0, 1000), at(1, 500), at(2, 510)] }

    it 'keeps the new readings' do
      expect(values).to eq([1000, 500, 510])
    end
  end

  context 'with a step back by rounding' do
    let(:readings) { [at(0, 1000.4), at(1, 1000)] }

    it 'keeps it' do
      expect(values).to eq([1000.4, 1000])
    end
  end
end
