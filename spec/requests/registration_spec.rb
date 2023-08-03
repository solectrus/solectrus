describe 'Registration', with_setup_id: true do
  describe 'GET /registration' do
    context 'when registration required' do
      before do
        allow(Rails.configuration.x).to receive(
          :registration_required,
        ).and_return(true)
      end

      context 'when admin logged in' do
        before { login_as_admin }

        it 'can redirect to registration url' do
          get '/registration'

          expect(response).to redirect_to(
            %r{https://registration.solectrus.de/\?id=\S+&return_to=\S+},
          )
        end

        it 'can complete registration' do
          allow(UpdateCheck.instance).to receive(:clear_cache)

          get '/registration/complete'

          expect(UpdateCheck.instance).to have_received(:clear_cache)
          expect(response).to redirect_to(root_path)
        end

        it 'can skip registration' do
          allow(UpdateCheck.instance).to receive(:skip_registration)

          get '/registration/skipped'

          expect(UpdateCheck.instance).to have_received(:skip_registration)
          expect(response).to redirect_to(root_path)
        end
      end

      context 'when admin NOT logged in' do
        it 'redirects to root' do
          get '/registration'

          expect(response).to redirect_to(root_path)
        end
      end
    end

    context 'when registration not required' do
      before do
        allow(Rails.configuration.x).to receive(
          :registration_required,
        ).and_return(false)
      end

      context 'when admin logged in' do
        before { login_as_admin }

        it 'redirects to root' do
          get '/registration'

          expect(response).to redirect_to(root_path)
        end
      end

      context 'when admin NOT logged in' do
        it 'redirects to root' do
          get '/registration'

          expect(response).to redirect_to(root_path)
        end
      end
    end
  end
end
