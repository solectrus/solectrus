describe SummarizerJob do
  subject(:job) { described_class.new }

  describe '#perform' do
    subject(:perform) { job.perform(date) }

    let(:date) { Date.current }
    let(:summarizer) { instance_double(Sensor::Summarizer) }

    before do
      allow(Sensor::Summarizer).to receive(:new).with(date).and_return(
        summarizer,
      )
      allow(summarizer).to receive(:call)
    end

    it 'creates and calls Sensor::Summarizer with the given date' do
      perform

      expect(Sensor::Summarizer).to have_received(:new).with(date)
      expect(summarizer).to have_received(:call)
    end
  end

  describe '.perform_for_timeframe' do
    let(:timeframe) { Timeframe.new('2023-01-02') }
    let(:dates) { [Date.parse('2023-01-01'), Date.parse('2023-01-02')] }

    before do
      allow(Summary).to receive(:missing_or_stale_days).and_return(dates)
      allow(described_class).to receive(:perform_now)
      allow(described_class).to receive(:perform_later)
    end

    context 'with valid parameters' do
      it 'calls Summary.missing_or_stale_days with correct parameters' do
        described_class.perform_for_timeframe(timeframe)

        expect(Summary).to have_received(:missing_or_stale_days).with(
          from: timeframe.effective_beginning_date,
          to: timeframe.effective_ending_date,
        )
      end

      it 'calls perform_now for each date by default' do
        described_class.perform_for_timeframe(timeframe)

        expect(described_class).to have_received(:perform_now).with(dates.first)
        expect(described_class).to have_received(:perform_now).with(
          dates.second,
        )
      end

      it 'calls perform_now when explicitly specified' do
        described_class.perform_for_timeframe(timeframe, :perform_now)

        expect(described_class).to have_received(:perform_now).with(dates.first)
        expect(described_class).to have_received(:perform_now).with(
          dates.second,
        )
      end

      it 'calls perform_later when specified' do
        described_class.perform_for_timeframe(timeframe, :perform_later)

        expect(described_class).to have_received(:perform_later).with(
          dates.first,
        )
        expect(described_class).to have_received(:perform_later).with(
          dates.second,
        )
      end

      it 'returns count of processed dates' do
        expect(described_class.perform_for_timeframe(timeframe)).to eq(2)
      end
    end

    context 'with invalid parameters' do
      it 'raises ArgumentError when timeframe is not a Timeframe' do
        expect do
          described_class.perform_for_timeframe('invalid')
        end.to raise_error(ArgumentError)
      end

      it 'raises ArgumentError when timeframe is now' do
        now_timeframe = Timeframe.now

        expect do
          described_class.perform_for_timeframe(now_timeframe)
        end.to raise_error(ArgumentError)
      end

      it 'raises ArgumentError when method is invalid' do
        expect do
          described_class.perform_for_timeframe(timeframe, :invalid_method)
        end.to raise_error(ArgumentError)
      end
    end
  end
end
