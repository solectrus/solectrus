describe ApplicationPolicy do
  subject { described_class }

  describe '.power_splitter?' do
    subject { described_class.power_splitter? }

    context 'when sponsoring' do
      before { allow(UpdateCheck).to receive(:sponsoring?).and_return(true) }

      it { is_expected.to be(true) }
    end

    context 'when eligible for free' do
      before do
        allow(UpdateCheck).to receive(:eligible_for_free?).and_return(true)
      end

      it { is_expected.to be(true) }
    end

    context 'when not sponsoring and not eligible for free' do
      it { is_expected.to be(false) }
    end
  end
end
