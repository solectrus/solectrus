describe ChargingSession::SocRuns do
  subject(:runs) { described_class.new(curve).call }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  context 'with a charge' do
    let(:curve) { [[at(8), 40], [at(9), 50], [at(10), 60]] }

    it 'gives one run with a step for each reading' do
      expect(runs).to eq([[[at(8), at(9), 10], [at(9), at(10), 10]]])
    end
  end

  context 'with a short pause' do
    let(:curve) { [[at(8), 40], [at(8, 30), 40], [at(9), 50]] }

    it 'keeps the pause in the run' do
      expect(runs).to eq([[[at(8), at(8, 30), 0], [at(8, 30), at(9), 10]]])
    end
  end

  context 'with a long pause' do
    let(:curve) { [[at(8), 40], [at(9), 50], [at(11), 50], [at(12), 60]] }

    it 'ends the run' do
      expect(runs.map { it.sum(&:last) }).to eq([10, 0, 10])
    end
  end

  context 'with a fall' do
    let(:curve) { [[at(8), 40], [at(9), 50], [at(10), 30], [at(11), 45]] }

    it 'ends the run' do
      expect(runs.map { it.sum(&:last) }).to eq([10, -20, 15])
    end
  end
end
