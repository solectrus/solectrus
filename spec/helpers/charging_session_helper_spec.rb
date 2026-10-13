describe ChargingSessionHelper do
  describe '#car_options' do
    subject { helper.car_options(charging_session) }

    let(:charging_session) { ChargingSession.new(kind: :wallbox, started_at: Time.zone.local(2026, 6, 10, 8), car:) }

    before do
      Car.create!(id: 1, name: 'Trabant')
      # The controller gives the selection (see CarSelectable)
      without_partial_double_verification do
        allow(helper).to receive(:car_selection).and_return(CarSelection.new(nil, timeframe: nil))
      end
    end

    context 'with a car of the configuration' do
      let(:car) { Car.find(1) }

      it { is_expected.to eq([['Trabant', 1]]) }
    end

    # A car without a configuration is no choice for a new session, but a
    # session keeps it, so saving the form does not move the session
    context 'with a car without a configuration' do
      let(:car) { Car.create!(id: 3, name: 'Wartburg') }

      it { is_expected.to eq([['Trabant', 1], ['Wartburg', 3]]) }
    end
  end
end
