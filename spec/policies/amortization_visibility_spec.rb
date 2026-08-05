describe AmortizationVisibility do
  subject(:visibility) { described_class.new(admin:) }

  let(:admin) { false }

  before { allow(ApplicationPolicy).to receive(:amortization?).and_return(true) }

  describe '.level' do
    it 'reads the two booleans as one three-state setting' do
      aggregate_failures do
        expect(level_for(enabled: true, public: true)).to eq('all')
        expect(level_for(enabled: true, public: false)).to eq('admins')
        expect(level_for(enabled: false, public: false)).to eq('none')

        # Disabled wins - the page is gone either way.
        expect(level_for(enabled: false, public: true)).to eq('none')
      end
    end

    def level_for(enabled:, public:)
      allow(Setting).to receive_messages(
        enable_amortization: enabled,
        amortization_public: public,
      )

      described_class.level
    end
  end

  describe '.level=' do
    # Writes the real settings, so every example has to put them back.
    after do
      Setting.enable_amortization = true
      Setting.amortization_public = false
    end

    it 'exposes the calculation to everyone' do
      described_class.level = 'all'

      expect(described_class.level).to eq('all')
    end

    it 'keeps it to admins' do
      described_class.level = 'admins'

      expect(described_class.level).to eq('admins')
    end

    it 'removes the page entirely' do
      described_class.level = 'none'

      aggregate_failures do
        expect(described_class.level).to eq('none')
        expect(described_class).not_to be_enabled
      end
    end

    # Exposing the calculation to non-admins is a sponsor feature.
    it 'falls back to admins-only without the sponsor feature' do
      allow(ApplicationPolicy).to receive(:amortization?).and_return(false)

      described_class.level = 'all'

      expect(described_class.level).to eq('admins')
    end

    it 'rejects anything else' do
      expect { described_class.level = 'everyone' }.to raise_error(
        ArgumentError,
      )
    end
  end

  describe '#unlocked?' do
    context 'when the calculation is public' do
      before { allow(described_class).to receive(:level).and_return('all') }

      it { is_expected.to be_unlocked }
    end

    context 'when it is not public' do
      before { allow(described_class).to receive(:level).and_return('admins') }

      it { is_expected.not_to be_unlocked }

      context 'with an admin' do
        let(:admin) { true }

        it { is_expected.to be_unlocked }
      end
    end
  end

  describe '#visible?' do
    before { allow(described_class).to receive(:level).and_return('all') }

    it { is_expected.to be_visible }

    context 'without the sponsor feature' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
      end

      # Unlocked, but nothing to unlock - the page promotes the feature instead.
      it { is_expected.not_to be_visible }
    end
  end

  describe '#denial_reason' do
    context 'when the calculation is public' do
      before { allow(described_class).to receive(:level).and_return('all') }

      it { expect(visibility.denial_reason).to be_nil }

      context 'without the sponsor feature' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
        end

        it { expect(visibility.denial_reason).to eq(:unavailable) }
      end
    end

    context 'when it is admins-only' do
      before { allow(described_class).to receive(:level).and_return('admins') }

      it { expect(visibility.denial_reason).to eq(:restricted) }

      # Checked before the licence on purpose: someone who only needs to log in
      # is told that, rather than being sent to the sponsor teaser.
      context 'without the sponsor feature' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
        end

        it { expect(visibility.denial_reason).to eq(:restricted) }
      end
    end
  end
end
