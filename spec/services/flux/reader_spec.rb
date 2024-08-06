describe Flux::Reader do
  subject(:reader) { described_class.new(sensors: []) }

  describe '#default_cache_options' do
    subject { reader.__send__(:default_cache_options) }

    before do
      travel_to Time.zone.local(2024, 8, 6, 8, 0, 0) # Tuesday

      reader.call(timeframe)
    end

    context 'when timeframe is now' do
      let(:timeframe) { Timeframe.now }

      it { is_expected.to eq({ expires_in: nil }) }
    end

    context 'when timeframe is day' do
      let(:timeframe) { Timeframe.day }

      it { is_expected.to eq({ expires_in: 1.minute }) }
    end

    context 'when timeframe is week' do
      let(:timeframe) { Timeframe.week }

      it { is_expected.to eq({ expires_in: 5.minutes }) }
    end

    context 'when timeframe is month' do
      let(:timeframe) { Timeframe.month }

      it { is_expected.to eq({ expires_in: 10.minutes }) }
    end

    context 'when timeframe is year' do
      let(:timeframe) { Timeframe.year }

      it { is_expected.to eq({ expires_in: 1.hour }) }
    end

    context 'when timeframe is all' do
      let(:timeframe) { Timeframe.new('all', min_date: Date.new(2024, 2, 1)) }

      it { is_expected.to eq({ expires_in: 1.day }) }
    end
  end
end
