describe 'RegistrationRequired' do
  context 'when grace period is not yet expired' do
    before do
      allow(UpdateCheck).to receive(
        :registration_grace_period_expired?,
      ).and_return(false)
    end

    describe 'GET /' do
      it 'redirects' do
        get '/inverter_power/now'

        expect(response).to be_successful
      end
    end

    describe 'GET /registration-required' do
      context 'when admin' do
        before { login_as_admin }

        it 'redirects' do
          get '/registration-required'

          expect(response).to redirect_to(root_path)
        end
      end

      context 'when not admin' do
        it 'redirects' do
          get '/registration-required'

          expect(response).to redirect_to(root_path)
        end
      end
    end
  end

  context 'when grace period is expired' do
    before do
      allow(UpdateCheck).to receive(
        :registration_grace_period_expired?,
      ).and_return(true)
    end

    describe 'GET /' do
      it 'redirects' do
        get '/inverter_power/now'

        expect(response).to redirect_to(registration_required_path)
      end
    end

    describe 'GET /registration-required' do
      context 'when admin' do
        before { login_as_admin }

        it 'shows the registration required page with continue button' do
          get '/registration-required'

          expect(response).to be_successful

          expect(response.body).to include(
            I18n.t('registration_required.show.continue'),
          )
          expect(response.body).not_to include(I18n.t('layout.login'))
        end
      end

      context 'when not admin' do
        it 'shows login required message and login button' do
          get '/registration-required'

          expect(response).to be_successful
          expect(response.body).not_to include(
            I18n.t('registration_required.show.continue'),
          )
          expect(response.body).to include(I18n.t('layout.login'))
        end
      end
    end
  end
end
