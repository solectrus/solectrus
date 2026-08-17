describe ApplicationPolicy do
  subject { described_class }

  # Which grant unlocks a feature is decided by the update server and read by
  # PremiumStatus. This policy only asks whether any grant applies.
  %i[power_splitter power_balance_chart mcp].each do |feature|
    describe ".#{feature}?" do
      subject { described_class.public_send(:"#{feature}?") }

      context 'when premium is active' do
        before { allow(PremiumStatus).to receive(:active?).and_return(true) }

        it { is_expected.to be(true) }
      end

      context 'when premium is not active' do
        before { allow(PremiumStatus).to receive(:active?).and_return(false) }

        it { is_expected.to be(false) }
      end
    end
  end

  describe 'an unknown feature' do
    before { allow(PremiumStatus).to receive(:active?).and_return(true) }

    it 'stays disabled' do
      expect(described_class.instance.feature_enabled?(:nonexistent)).to be(
        false,
      )
    end
  end
end
