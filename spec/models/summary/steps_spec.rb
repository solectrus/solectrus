describe Summary::Steps do
  describe '.versions' do
    it 'gives the version of each step' do
      expect(described_class.versions).to eq(
        'charging_sessions' => ChargingSession::Detection::VERSION,
      )
    end
  end

  describe '.parse' do
    it 'takes the known steps of a parameter' do
      expect(described_class.parse('charging_sessions,unknown')).to eq([:charging_sessions])
    end

    it 'takes nothing without a parameter' do
      expect(described_class.parse(nil)).to eq([])
    end
  end

  describe '.[]' do
    it 'finds a step by its key' do
      expect(described_class[:charging_sessions]).to eq(ChargingSession::Detection)
    end

    it 'rejects an unknown key' do
      expect { described_class[:unknown] }.to raise_error(ArgumentError)
    end
  end
end
