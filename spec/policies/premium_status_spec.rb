describe PremiumStatus do
  before do
    allow(UpdateCheck).to receive_messages(
      premium_reason: nil,
      premium_ends_at: nil,
    )
  end

  describe '.reason' do
    subject { described_class.reason }

    context 'when the server names a reason' do
      before do
        allow(UpdateCheck).to receive(:premium_reason).and_return(:intro)
      end

      it { is_expected.to eq(:intro) }
    end

    context 'when running without an update server' do
      before do
        allow(UpdateCheck).to receive(:premium_reason).and_return(:development)
      end

      it { is_expected.to eq(:development) }
    end

    # A later release of the update server can add a grant. It reaches this app
    # before the release that knows the name, and it must open the features all
    # the same.
    context 'when the server names a reason this release does not know' do
      before do
        allow(UpdateCheck).to receive(:premium_reason).and_return(:whatever)
      end

      it { is_expected.to eq(:whatever) }
    end

    context 'when the server names no reason' do
      it { is_expected.to be_nil }
    end
  end

  describe '.active?' do
    subject { described_class.active? }

    context 'with a reason' do
      before do
        allow(UpdateCheck).to receive(:premium_reason).and_return(:intro)
      end

      it { is_expected.to be(true) }
    end

    context 'with a reason this release does not know' do
      before do
        allow(UpdateCheck).to receive(:premium_reason).and_return(:whatever)
      end

      it { is_expected.to be(true) }
    end

    context 'without a reason' do
      it { is_expected.to be(false) }
    end

    # The update server drops the reason when a grant ends, but its last answer
    # outlives that moment - it is served for another day during an outage, and
    # it waits in a cache the installation itself holds.
    context 'with a reason whose end has passed' do
      before do
        allow(UpdateCheck).to receive_messages(
          premium_reason: :intro,
          premium_ends_at: 1.minute.ago,
        )
      end

      it { is_expected.to be(false) }
    end

    context 'with a reason that ends in the future' do
      before do
        allow(UpdateCheck).to receive_messages(
          premium_reason: :free_trial,
          premium_ends_at: 1.minute.from_now,
        )
      end

      it { is_expected.to be(true) }
    end
  end

  describe '.ends_at' do
    subject { described_class.ends_at }

    let(:ends_at) { 2.days.from_now.change(usec: 0) }

    context 'when in the intro phase' do
      before do
        allow(UpdateCheck).to receive_messages(
          premium_reason: :intro,
          premium_ends_at: ends_at,
        )
      end

      it { is_expected.to eq(ends_at) }
    end

    context 'when a free trial runs' do
      before do
        allow(UpdateCheck).to receive_messages(
          premium_reason: :free_trial,
          premium_ends_at: ends_at,
        )
      end

      it { is_expected.to eq(ends_at) }
    end

    # The answer decides, not a list of names here. A subscription runs until
    # it is cancelled, so the server sends no end for it.
    context 'when sponsoring' do
      before do
        allow(UpdateCheck).to receive(:premium_reason).and_return(:sponsoring)
      end

      it { is_expected.to be_nil }
    end

    context 'when the grant has a name this release does not know' do
      before do
        allow(UpdateCheck).to receive_messages(
          premium_reason: :whatever,
          premium_ends_at: ends_at,
        )
      end

      it { is_expected.to eq(ends_at) }
    end

    context 'when nothing applies' do
      it { is_expected.to be_nil }
    end
  end
end
