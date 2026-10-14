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

  describe '.input_value' do
    it { expect(described_class.input_value(BigDecimal('13.9'))).to eq('13.90') }
    it { expect(described_class.input_value(BigDecimal(5))).to eq('5.00') }
    it { expect(described_class.input_value(BigDecimal('110.71'))).to eq('110.71') }
    it { expect(described_class.input_value(BigDecimal('0.30912'))).to eq('0.30912') }
    it { expect(described_class.input_value(BigDecimal('-229.1'))).to eq('-229.10') }
    it { expect(described_class.input_value(nil)).to be_nil }
  end
end
