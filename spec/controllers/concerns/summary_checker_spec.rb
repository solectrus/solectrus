describe 'SummaryChecker' do
  controller { include SummaryChecker }

  before { travel_to Time.zone.local(2024, 10, 20, 12, 0, 0) }

  describe '#load_missing_or_stale_summary_days' do
    subject(:load_days) { controller.load_missing_or_stale_summary_days(timeframe) }

    context 'when all days are missing' do
      context 'when timeframe is "now"' do
        let(:timeframe) { Timeframe.now }

        it { is_expected.to eq([]) }
      end

      # A day or two build right away (see Sensor::Summarizer.build_few)
      context 'when timeframe is "day"' do
        let(:timeframe) { Timeframe.day }

        before { allow(Sensor::Summarizer).to receive(:new).and_call_original }

        it { is_expected.to eq([]) }

        it 'builds the day itself' do
          load_days

          expect(Sensor::Summarizer).to have_received(:new).with([Date.current])
        end
      end

      context 'when timeframe is "week"' do
        let(:timeframe) { Timeframe.week }

        it { is_expected.to have_attributes(length: 7) }
      end

      context 'when timeframe is "month"' do
        let(:timeframe) { Timeframe.month }

        it { is_expected.to have_attributes(length: 20) }
      end

      context 'when timeframe is "year"' do
        let(:timeframe) { Timeframe.year }

        it { is_expected.to have_attributes(length: 294) }
      end

      context 'when timeframe is "all"' do
        let(:timeframe) { Timeframe.all }

        it { is_expected.to have_attributes(length: 1424) }
      end
    end
  end
end
