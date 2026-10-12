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

  describe '#charging_session_time_range' do
    subject { helper.charging_session_time_range(charging_session) }

    let(:charging_session) do
      ChargingSession.new(kind: :offsite, started_at: Time.zone.local(2025, 12, 31, 22, 0), ended_at:)
    end

    context 'when the session ends on the same day' do
      let(:ended_at) { Time.zone.local(2025, 12, 31, 23, 15) }

      it { is_expected.to eq('22:00–23:15') }
    end

    context 'when the session ends on the next day' do
      let(:ended_at) { Time.zone.local(2026, 1, 1, 3, 0) }

      it { is_expected.to eq('22:00 – 01 Jan 03:00') }
    end

    context 'without an end' do
      let(:ended_at) { nil }

      it { is_expected.to eq('22:00') }
    end

    context 'when the session is ongoing' do
      let(:charging_session) do
        ChargingSession.new(kind: :wallbox, started_at:, ended_at: started_at + 15.minutes, ongoing: true)
      end

      before { travel_to(Time.zone.local(2026, 10, 12, 12, 40)) }

      context 'when it started today' do
        let(:started_at) { Time.zone.local(2026, 10, 12, 12, 20) }

        it { is_expected.to eq('since 12:20') }
      end

      context 'when it started yesterday' do
        let(:started_at) { Time.zone.local(2026, 10, 11, 23, 30) }

        it { is_expected.to eq('since 11 Oct 23:30') }
      end
    end
  end

  describe '#charging_session_soc_range' do
    subject { helper.charging_session_soc_range(charging_session) }

    let(:charging_session) { ChargingSession.new(kind: :wallbox, soc_from: 64, soc_to: 65) }

    it { is_expected.to eq('64 → 65%') }

    context 'when the session is ongoing' do
      before { charging_session.ongoing = true }

      it { is_expected.to eq('from 64%') }
    end
  end
end
