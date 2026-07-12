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

      context 'with drill-down filters' do
        before do
          CashFlow.create!(
            date: Date.new(2021, 3, 1),
            amount: -5000,
            category: 'investment',
            note: 'Panels',
          )
          CashFlow.create!(
            date: Date.new(2021, 5, 1),
            amount: 800,
            category: 'subsidy',
            note: 'Grant',
          )
          CashFlow.create!(
            date: Date.new(2023, 6, 1),
            amount: -200,
            category: 'repair',
            note: 'Inverter fix',
          )
        end

        it 'filters by category' do
          get '/settings/cash_flows', params: { category: 'investment' }

          aggregate_failures do
            expect(response.body).to include('Panels')
            expect(response.body).not_to include('Grant')
            expect(response.body).not_to include('Inverter fix')
          end
        end

        it 'filters by an inclusive date range' do
          get '/settings/cash_flows',
              params: {
                from: '2021-01-01',
                to: '2021-12-31',
              }

          aggregate_failures do
            expect(response.body).to include('Panels')
            expect(response.body).to include('Grant')
            expect(response.body).not_to include('Inverter fix')
          end
        end

        it 'combines category and range (the amortization drill-down)' do
          get '/settings/cash_flows',
              params: {
                category: 'investment',
                to: '2021-12-31',
              }

          aggregate_failures do
            expect(response.body).to include('Panels')
            expect(response.body).not_to include('Grant')
            expect(response.body).not_to include('Inverter fix')
          end
        end

        it 'filters by several categories at once (the group drill-down)' do
          get '/settings/cash_flows',
              params: {
                category: %w[investment repair],
              }

          aggregate_failures do
            expect(response.body).to include('Panels')
            expect(response.body).to include('Inverter fix')
            expect(response.body).not_to include('Grant')
          end
        end

        it 'shows the active filter with a way back to the full list' do
          get '/settings/cash_flows', params: { category: 'repair' }

          aggregate_failures do
            expect(response.body).to include('Clear filter')
            expect(response.body).to include('href="/settings/cash_flows"')
          end
        end

        it 'offers a per-row link to filter by the row category' do
          get '/settings/cash_flows'

          expect(response.body).to include(
            'href="/settings/cash_flows?category=investment"',
          )
        end

        it 'preselects a single active category filter in the new form' do
          get '/settings/cash_flows', params: { category: 'investment' }
          get '/settings/cash_flows/new'

          expect(response.body).to include(
            'selected="selected" value="investment"',
          )
        end

        it 'preselects the first category of a group filter' do
          get '/settings/cash_flows', params: { category: %w[repair investment] }
          get '/settings/cash_flows/new'

          expect(response.body).to include(
            'selected="selected" value="repair"',
          )
        end

        it 'omits the row link for the category already filtered alone' do
          get '/settings/cash_flows', params: { category: 'investment' }

          expect(response.body).not_to include(
            'href="/settings/cash_flows?category=investment"',
          )
        end

        it 'ignores an unknown category and shows the full list' do
          get '/settings/cash_flows', params: { category: 'bogus' }

          aggregate_failures do
            expect(response.body).to include('Panels')
            expect(response.body).to include('Grant')
            expect(response.body).to include('Inverter fix')
            expect(response.body).not_to include('Clear filter')
          end
        end
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

      it 'refreshes the list in place' do
        post '/settings/cash_flows', params: valid_params, as: :turbo_stream

        aggregate_failures do
          expect(response.body).to include(
            'turbo-stream action="update" target="list"',
          )
          expect(response.body).to include('PV system')
        end
      end

      it 'keeps an active filter applied after creating an entry' do
        CashFlow.create!(
          date: Date.new(2021, 3, 1),
          amount: -5000,
          category: 'investment',
          note: 'Panels',
        )

        # Viewing the filtered list remembers the filter for the next mutation.
        get '/settings/cash_flows', params: { category: 'investment' }

        # The new subsidy is outside the active filter.
        post '/settings/cash_flows',
             params: {
               cash_flow: {
                 date: '2021-05-01',
                 amount: '800',
                 note: 'Grant',
                 category: 'subsidy',
               },
             },
             as: :turbo_stream

        aggregate_failures do
          expect(response.body).to include('Panels')
          expect(response.body).not_to include('Grant')
        end
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
              params: { setting: { amortization_visibility: 'all' } }

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin with sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        login_as_admin
      end

      it 'shows the calculation to all users' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_visibility: 'all' } }

        expect(Setting.enable_amortization).to be(true)
        expect(Setting.amortization_public).to be(true)
      end

      it 'shows the calculation to admins only' do
        Setting.amortization_public = true

        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_visibility: 'admins' } }

        expect(Setting.enable_amortization).to be(true)
        expect(Setting.amortization_public).to be(false)
      end

      it 'hides the page from everyone' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_visibility: 'none' } }

        expect(Setting.enable_amortization).to be(false)
      end

      it 'rejects an unknown visibility without changing the setting' do
        Setting.enable_amortization = true

        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_visibility: 'bogus' } }

        aggregate_failures do
          expect(response).to have_http_status(:unprocessable_content)
          expect(Setting.enable_amortization).to be(true)
        end
      end
    end

    context 'when logged in as admin without sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
        login_as_admin
      end

      it 'keeps the calculation private even when set to all' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_visibility: 'all' } }

        expect(Setting.enable_amortization).to be(true)
        expect(Setting.amortization_public).to be(false)
      end

      it 'still hides the page from everyone' do
        patch '/settings/cash_flows/visibility',
              params: { setting: { amortization_visibility: 'none' } }

        expect(Setting.enable_amortization).to be(false)
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
