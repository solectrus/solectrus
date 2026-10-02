describe ChargingSessionHelper do
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
  end
end
