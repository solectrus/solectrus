describe ApplicationHelper do
  describe '#banner?' do
    subject { helper.banner? }

    context 'when controller is an ErrorsController' do
      before do
        allow(helper).to receive(:controller).and_return(ErrorsController.new)
      end

      it { is_expected.to be(false) }
    end

    context 'when the banner is snoozed' do
      before do
        allow(UpdateCheck).to receive(:snoozed_banner?).and_return(true)
      end

      it { is_expected.to be(false) }
    end

    # The sponsoring question is answered elsewhere and must not silence the
    # registration, which is the deadline that stops the installation.
    context 'when only the sponsoring prompt is skipped' do
      before do
        allow(UpdateCheck).to receive_messages(
          skipped_prompt?: true,
          unregistered?: true,
          registration_reminder_due?: true,
        )
      end

      it { is_expected.to be(true) }
    end

    context 'when the registration reminder is due' do
      before do
        allow(UpdateCheck).to receive_messages(
          unregistered?: true,
          registration_reminder_due?: true,
        )
      end

      it { is_expected.to be(true) }
    end

    # A fresh installation is explored first, without being asked for anything.
    context 'when unregistered but still within the quiet period' do
      before do
        allow(UpdateCheck).to receive_messages(
          unregistered?: true,
          registration_reminder_due?: false,
        )
      end

      it { is_expected.to be(false) }
    end

    # The banner only knows how to ask for a registration. A reminder that
    # outlives the registration would render an empty bar.
    context 'when the reminder is due but the registration is there' do
      before do
        allow(UpdateCheck).to receive_messages(
          unregistered?: false,
          registration_reminder_due?: true,
        )
      end

      it { is_expected.to be(false) }
    end
  end

  describe '#extra_stimulus_controllers' do
    subject { helper.content_for(:extra_stimulus_controllers) }

    before { helper.extra_stimulus_controllers('controller1', 'controller2') }

    it { is_expected.to eq('controller1 controller2') }
  end
end
