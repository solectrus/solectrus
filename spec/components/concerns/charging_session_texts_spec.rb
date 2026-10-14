describe ChargingSessionTexts, type: :component do
  # A component translates only once it renders, and it renders only with
  # a name
  let(:component_class) do
    klass = Class.new(ViewComponent::Base) do
      include ChargingSessionTexts

      attr_reader :charging_session

      def initialize(charging_session)
        super()
        @charging_session = charging_session
      end

      def call = ''
    end
    stub_const('ChargingSessionTextsComponent', klass)
  end

  def texts(charging_session)
    component_class.new(charging_session).tap { render_inline(it) }
  end

  describe '#time_range' do
    subject { texts(charging_session).time_range }

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

  describe '#soc_range' do
    subject { texts(charging_session).soc_range }

    let(:charging_session) { ChargingSession.new(kind: :wallbox, soc_from: 64, soc_to: 65) }

    it { is_expected.to eq('64 → 65%') }

    context 'when the session is ongoing' do
      before { charging_session.ongoing = true }

      it { is_expected.to eq('from 64%') }
    end
  end
end
