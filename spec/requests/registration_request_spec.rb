describe 'Registration', with_setup_id: 0 do
  describe 'GET /registration' do
    context 'when admin logged in' do
      before { login_as_admin }

      it 'can redirect to registration url' do
        get '/registration'

        expect(response).to redirect_to(
          %r{https://registration.solectrus.de/\?id=\S+&return_to=\S+},
        )
      end

      it 'can complete registration' do
        allow(UpdateCheck).to receive(:clear_cache!)

        get '/registration/complete'

        expect(UpdateCheck).to have_received(:clear_cache!)
        expect(response).to redirect_to(balance_home_path)
      end

      it 'can skip the sponsoring prompt' do
        allow(UpdateCheck).to receive(:skip_prompt!)

        get '/registration/skip'

        expect(UpdateCheck).to have_received(:skip_prompt!)
        expect(response).to redirect_to(balance_home_path)
      end

      # Closing the banner answers the registration question, not the
      # sponsoring one.
      it 'can snooze the registration banner' do
        allow(UpdateCheck).to receive_messages(
          snooze_banner!: nil,
          skip_prompt!: nil,
        )

        get '/registration/snooze'

        expect(UpdateCheck).to have_received(:snooze_banner!)
        expect(UpdateCheck).not_to have_received(:skip_prompt!)
        expect(response).to redirect_to(balance_home_path)
      end
    end

    context 'when admin NOT logged in' do
      it 'redirects to root' do
        get '/registration'

        expect(response).to redirect_to(balance_home_path)
      end
    end
  end
end
