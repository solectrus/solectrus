describe Currency do
  describe '.code' do
    subject { described_class.code }

    before { allow(Rails.configuration.x).to receive(:currency).and_return('CHF') }

    it { is_expected.to eq('CHF') }
  end

  describe '.symbol' do
    subject { described_class.symbol }

    context 'when the configured currency has a known symbol' do
      before { allow(Rails.configuration.x).to receive(:currency).and_return('USD') }

      it { is_expected.to eq('$') }
    end

    context 'when the configured currency has no known symbol' do
      before { allow(Rails.configuration.x).to receive(:currency).and_return('CHF') }

      it 'falls back to the code itself' do
        is_expected.to eq('CHF')
      end
    end

    context 'with the default currency' do
      it { is_expected.to eq('€') }
    end

    context 'with an explicit code' do
      it { expect(described_class.symbol('GBP')).to eq('£') }
      it { expect(described_class.symbol('SEK')).to eq('SEK') }
    end
  end
end
