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

    context 'when free trial is active' do
      before do
        allow(UpdateCheck).to receive(:free_trial?).and_return(true)
      end

      it { is_expected.to be(true) }
    end

    context 'when not sponsoring, not eligible for free, and no free trial' do
      before do
        allow(UpdateCheck).to receive_messages(
          sponsoring?: false,
          eligible_for_free?: false,
          free_trial?: false,
        )
      end

      it { is_expected.to be(false) }
    end
  end

  describe '.power_balance_chart?' do
    subject { described_class.power_balance_chart? }

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

    context 'when free trial is active' do
      before do
        allow(UpdateCheck).to receive(:free_trial?).and_return(true)
      end

      it { is_expected.to be(true) }
    end

    context 'when not sponsoring, not eligible for free, and no free trial' do
      before do
        allow(UpdateCheck).to receive_messages(
          sponsoring?: false,
          eligible_for_free?: false,
          free_trial?: false,
        )
      end

      it { is_expected.to be(false) }
    end
  end
end
