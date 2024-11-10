describe ApplicationHelper do
  describe '#banner?' do
    subject { helper.banner? }

    context 'when controller is an ErrorsController' do
      before do
        allow(helper).to receive(:controller).and_return(ErrorsController.new)
      end

      it { is_expected.to be(false) }
    end

    context 'when skipped prompt' do
      before do
        allow(UpdateCheck).to receive(:skipped_prompt?).and_return(true)
      end

      it { is_expected.to be(false) }
    end

    context 'when unregistered' do
      before { allow(UpdateCheck).to receive(:unregistered?).and_return(true) }

      it { is_expected.to be(true) }
    end

    context 'when registered' do
      before { allow(UpdateCheck).to receive(:unregistered?).and_return(false) }

      it { is_expected.to be(false) }
    end
  end

  describe '#extra_stimulus_controllers' do
    subject { helper.content_for(:extra_stimulus_controllers) }

    before { helper.extra_stimulus_controllers('controller1', 'controller2') }

    it { is_expected.to eq('controller1 controller2') }
  end
end
