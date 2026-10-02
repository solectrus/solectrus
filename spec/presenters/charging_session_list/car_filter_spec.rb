describe ChargingSessionList::CarFilter do
  let(:cars) { [Car.new(id: 1), Car.new(id: 2)] }

  describe '.from_param' do
    it 'filters by a car of the installation' do
      expect(described_class.from_param('2', cars:).scope_value).to eq(2)
    end

    it 'filters the sessions that are not assigned and the guest sessions' do
      expect(described_class.from_param('not_assigned', cars:).scope_value).to eq(:not_assigned)
      expect(described_class.from_param('guest', cars:).scope_value).to eq(:guest)
    end

    it 'shows all sessions without a parameter and for a number without a car' do
      [nil, '5', 'x'].each do |param|
        expect(described_class.from_param(param, cars:).scope_value).to be_nil
      end
    end
  end

  it 'drops the guest filter in the list of the offsite sessions' do
    filter = described_class.from_param('guest', cars:)

    expect(filter.to_param_for('wallbox')).to eq('guest')
    expect(filter.to_param_for('offsite')).to be_nil
  end
end
