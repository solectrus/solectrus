describe String do
  describe '#to_utf8' do
    subject { string.to_utf8 }

    context 'when string is encoded as UTF-8' do
      let(:string) { '5 °C'.force_encoding(Encoding::UTF_8) }

      it { is_expected.to eq('5 °C') }
    end

    context 'when string is encoded as ASCII-8BIT' do
      let(:string) { '5 °C'.force_encoding(Encoding::ASCII_8BIT) }

      it { is_expected.to eq('5 °C') }
    end

    context 'when string is nil' do
      let(:string) { nil }

      it { is_expected.to be_nil }
    end
  end
end
