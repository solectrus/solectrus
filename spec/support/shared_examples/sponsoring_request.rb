shared_examples_for 'sponsoring redirects' do |action|
  context 'without sponsorship' do
    before do
      allow(UpdateCheck).to receive_messages(
        prompt?: true,
        skipped_prompt?: false,
      )
    end

    it 'redirects to sponsoring page' do
      get action

      expect(response).to redirect_to(sponsoring_path)
    end
  end

  context 'without sponsorship, but skipped' do
    before do
      allow(UpdateCheck).to receive_messages(
        prompt?: true,
        skipped_prompt?: true,
      )
    end

    it 'does not redirect to sponsoring page' do
      get action

      expect(response).not_to redirect_to(sponsoring_path)
    end
  end

  context 'with sponsorship, but skipped' do
    before { allow(UpdateCheck).to receive_messages(prompt?: false) }

    it 'does not redirect to sponsoring page' do
      get action

      expect(response).not_to redirect_to(sponsoring_path)
    end
  end
end
