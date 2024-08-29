describe Flux::Reader do
  subject(:reader) { described_class.new(sensors: []) }

  describe '#default_cache_options' do
    subject { reader.__send__(:default_cache_options) }

    before { reader.call(timeframe) }

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it { is_expected.to be_nil }
    end

    context 'when timeframe is day' do
      let(:timeframe) { Timeframe.day }

      it { is_expected.to eq({ expires_in: 1.minute }) }
    end

    context 'when timeframe is week' do
      let(:timeframe) { Timeframe.new('2024-W32') }

      context "when it's Tuesday" do
        before { travel_to Time.zone.local(2024, 8, 6, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 3.minutes }) }
      end

      context "when it's Sunday" do
        before { travel_to Time.zone.local(2024, 8, 11, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 13.minutes }) }
      end
    end

    context 'when timeframe is month' do
      let(:timeframe) { Timeframe.new('2024-08') }

      context 'when it is the beginning of the month' do
        before { travel_to Time.zone.local(2024, 8, 3, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 5.minutes }) }
      end

      context 'when it is the end of the month' do
        before { travel_to Time.zone.local(2024, 8, 30, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 59.minutes }) }
      end
    end

    context 'when timeframe is year' do
      let(:timeframe) { Timeframe.new('2024') }

      context 'when it is the beginning of the year' do
        before { travel_to Time.zone.local(2024, 1, 6, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 11.minutes }) }
      end

      context 'when it is the end of the year' do
        before { travel_to Time.zone.local(2024, 12, 20, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 709.minutes }) }
      end
    end

    context 'when timeframe is all' do
      let(:timeframe) { Timeframe.new('all', min_date: Date.new(2023, 2, 1)) }

      context 'when shortly after commissioning' do
        before { travel_to Time.zone.local(2023, 3, 6, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 67.minutes }) }
      end

      context 'when long after commissioning' do
        before { travel_to Time.zone.local(2026, 12, 6, 8, 0, 0) }

        it { is_expected.to eq({ expires_in: 2809.minutes }) }
      end
    end
  end
end
