describe Summary::Steps do
  # The test configuration has a wallbox and the state of charge of the first
  # car, but no location
  describe '.versions' do
    it 'gives the version of each step with something to do' do
      expect(described_class.versions).to eq(
        'charging_sessions' => ChargingSession::Detection::VERSION,
        'offsite_sessions' => ChargingSession::OffsiteDetection::VERSION,
      )
    end
  end

  describe '.sensor_names' do
    it 'names the sensors of the steps with something to do' do
      expect(described_class.sensor_names).to include(:wallbox_power, :wallbox_car_connected, :car_battery_soc_1, :car_connected_1)
    end

    it 'names each sensor once' do
      expect(described_class.sensor_names).to eq(described_class.sensor_names.uniq)
    end
  end

  describe '.derived' do
    it 'names the visits, but not the charging sessions with the changes of the user' do
      expect(described_class.derived).to eq([PlaceVisit])
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
