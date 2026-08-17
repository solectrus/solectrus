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
