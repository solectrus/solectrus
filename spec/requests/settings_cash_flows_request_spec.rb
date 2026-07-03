describe 'Settings::CashFlows' do
  let(:valid_params) do
    { cash_flow: { date: '2023-08-01', amount: '-5000', note: 'PV system' } }
  end

  describe 'GET /settings/cash_flows' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/settings/cash_flows'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        CashFlow.create!(date: Date.current, amount: -100, note: 'Test')

        get '/settings/cash_flows'
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Test')
      end
    end
  end

  describe 'POST /settings/cash_flows' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        post '/settings/cash_flows', params: valid_params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'creates a cash flow' do
        expect do
          post '/settings/cash_flows', params: valid_params
        end.to change(CashFlow, :count).by(1)

        expect(CashFlow.last.amount).to eq(-5000)
      end

      it 'rejects a zero amount' do
        post '/settings/cash_flows',
             params: {
               cash_flow: {
                 date: '2023-08-01',
                 amount: '0',
                 note: 'Invalid',
               },
             }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH /settings/cash_flows/:id' do
    let(:cash_flow) do
      CashFlow.create!(date: Date.current, amount: -100, note: 'Old')
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'updates the cash flow' do
        patch "/settings/cash_flows/#{cash_flow.id}",
              params: {
                cash_flow: {
                  note: 'New',
                },
              }

        expect(cash_flow.reload.note).to eq('New')
      end
    end
  end

  describe 'PATCH /settings/cash_flows/visibility' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_public: '1' } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin with sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        login_as_admin
      end

      it 'enables public visibility' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_public: '1' } }

        expect(Setting.amortization_public).to be(true)
      end

      it 'disables public visibility' do
        Setting.amortization_public = true

        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_public: '0' } }

        expect(Setting.amortization_public).to be(false)
      end
    end

    context 'when logged in as admin without sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
        login_as_admin
      end

      it 'ignores the setting' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_public: '1' } }

        expect(Setting.amortization_public).to be(false)
      end
    end
  end

  describe 'DELETE /settings/cash_flows/:id' do
    let!(:cash_flow) do
      CashFlow.create!(date: Date.current, amount: -100, note: 'Old')
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'deletes the cash flow' do
        expect do
          delete "/settings/cash_flows/#{cash_flow.id}"
        end.to change(CashFlow, :count).by(-1)
      end
    end
  end
end
