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

  describe '#honeybadger_api_key' do
    subject { helper.honeybadger_api_key }

    before do
      allow(Rails.configuration.x.honeybadger).to receive(:api_key).and_return(
        'secret',
      )
      helper.request.user_agent = user_agent
    end

    context 'with a supported browser' do
      let(:user_agent) do
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15'
      end

      it { is_expected.to eq('secret') }
    end

    # The browser check can be skipped, but such a browser cannot parse all of
    # the JavaScript
    context 'with a browser below the minimum version' do
      let(:user_agent) do
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_6) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.6.8 Safari/605.1.15'
      end

      it { is_expected.to be_nil }
    end
  end
end
