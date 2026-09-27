describe 'Sponsorings' do
  describe 'GET /show' do
    context 'when not sponsoring' do
      before do
        allow(UpdateCheck).to receive(
          :registration_grace_period_expired?,
        ).and_return(false)
        allow(PremiumStatus).to receive(:reason).and_return(nil)
      end

      it 'returns http success' do
        get '/sponsoring'
        expect(response).to have_http_status(:success)
      end

      # Every teaser and the sidebar box lead here, and two of them name the
      # free month. A page that then speaks only about the subscription loses
      # the visitor who came for the month.
      context 'when the free month is still unused' do
        before do
          allow(PremiumStatus).to receive(:trial_available?).and_return(true)
        end

        it 'names the month' do
          login_as_admin
          get '/sponsoring'

          expect(response.body).to include('free month')
        end

        # Only an admin can start the month. Anybody else reads it as the one
        # way to get past this page, and after the login it is shown anyway.
        it 'does not name it without an admin session' do
          get '/sponsoring'

          expect(response.body).not_to include('free month')
        end
      end

      # "Maybe later" records the skip, and that only works for an admin -
      # everyone else would be sent back here at once.
      context 'with an admin session' do
        before { login_as_admin }

        it 'offers maybe later next to the options' do
          get '/sponsoring'

          expect(response.body).to include('/registration/skip').and include(
                  'Maybe later',
                ).and include('See sponsorship options')
        end
      end

      context 'without an admin session' do
        it 'does not offer maybe later' do
          get '/sponsoring'

          expect(response.body).not_to include('/registration/skip')
        end

        it 'asks for the login to close the page' do
          get '/sponsoring'

          expect(response.body).to include('To close this notice').and include(
                  new_session_path(return_to: sponsoring_path),
                )
        end
      end

      context 'when the free month is used up' do
        before do
          allow(PremiumStatus).to receive(:trial_available?).and_return(false)
          login_as_admin
        end

        it 'says nothing about it' do
          get '/sponsoring'

          expect(response.body).not_to include('free month')
        end
      end
    end

    context 'when sponsoring' do
      before { allow(PremiumStatus).to receive(:reason).and_return(:sponsoring) }

      it 'redirects' do
        get '/sponsoring'
        expect(response).to redirect_to(balance_home_path)
      end
    end

    context 'when eligible for free' do
      before do
        allow(PremiumStatus).to receive(:reason).and_return(:eligible_for_free)
      end

      it 'redirects' do
        get '/sponsoring'
        expect(response).to redirect_to(balance_home_path)
      end
    end

    # These grants end. The question is not settled for them, and the page is
    # also where the free month is started.
    context 'when the grant ends' do
      before { allow(PremiumStatus).to receive(:reason).and_return(:intro) }

      it 'renders' do
        get '/sponsoring'
        expect(response).to have_http_status(:success)
      end
    end
  end
end
