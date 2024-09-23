require 'rails_helper'

describe 'Sponsorings' do
  describe 'GET /show' do
    context 'when not sponsoring' do
      it 'returns http success' do
        get '/sponsoring'
        expect(response).to have_http_status(:success)
      end
    end

    context 'when sponsoring' do
      before { allow(UpdateCheck).to receive(:sponsoring?).and_return(true) }

      it 'redirects' do
        get '/sponsoring'
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when eligible for free' do
      before do
        allow(UpdateCheck).to receive(:eligible_for_free?).and_return(true)
      end

      it 'redirects' do
        get '/sponsoring'
        expect(response).to redirect_to(root_path)
      end
    end
  end
end
