describe 'Amortization' do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Date.new(2024, 6, 15)

    # Runs transactional, so this does not affect the suite-wide seed data
    # created for system tests (which may exist when suites run together)
    Summary.delete_all
  end

  describe 'GET /amortization' do
    # By default treat the daily summaries as complete, so the calculation runs.
    # The dedicated context below covers the incomplete case.
    before { allow(Summary).to receive(:missing_or_stale_days).and_return([]) }

    context 'without any cash flows' do
      # Make the page visible to non-admins; the visibility gate itself is
      # covered separately below.
      before do
        allow(Setting).to receive(:amortization_public).and_return(true)
      end

      context 'with sponsoring' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        end

        it 'shows a hint to record cash flows' do
          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('No cash flows recorded yet')
        end

        it 'offers admins a link to manage cash flows' do
          login_as_admin

          get '/amortization'

          expect(response.body).to include('Manage cash flows')
          expect(response.body).to include('/settings/cash_flows')
        end
      end

      context 'without sponsoring' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
        end

        it 'shows the sponsor hint' do
          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Exclusively for sponsors')
        end
      end
    end

    context 'with cash flows and measured savings' do
      before do
        CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')

        create_summary(
          date: Date.new(2023, 8, 10),
          values: [
            [:house_power, :sum, 10_000],
            [:grid_import_power, :sum, 0],
            [:grid_export_power, :sum, 0],
          ],
        )
      end

      context 'when not logged in, sponsoring active and made public' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
          allow(Setting).to receive(:amortization_public).and_return(true)
        end

        it 'shows the same detail view, but without the parameter sliders' do
          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Nominal balance today')
          expect(response.body).to include('amortization-chart--component')
          expect(response.body).not_to include('type="range"')
        end
      end

      context 'when not logged in and not made public' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
          allow(Setting).to receive(:amortization_public).and_return(false)
        end

        it 'hides the calculation behind an admin-only hint' do
          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include(
            'only visible to administrators',
          )
          expect(response.body).not_to include('Nominal balance today')
        end
      end

      context 'when not logged in, made public but without sponsoring' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
          allow(Setting).to receive(:amortization_public).and_return(true)
        end

        it 'shows the sponsor hint instead of details' do
          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Exclusively for sponsors')
          expect(response.body).not_to include('Nominal balance today')
        end
      end

      context 'when logged in as admin without sponsoring' do
        before { login_as_admin }

        it 'shows the sponsor hint instead of details' do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(false)

          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Exclusively for sponsors')
        end
      end

      context 'when logged in as admin with sponsoring' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
          login_as_admin
        end

        it 'shows the detail view even when not made public' do
          allow(Setting).to receive(:amortization_public).and_return(false)

          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Nominal balance today')
          expect(response.body).to include('amortization-chart--component')
        end

        it 'renders the parameter sliders inside the detail frame' do
          get '/amortization'

          expect(response.body).to include('id="amortization_detail"')
          expect(response.body).to include('name="amortization[period_years]"')
          expect(response.body).to include('name="amortization[interest_rate]"')
          expect(response.body).to include('type="range"')
        end
      end
    end

    context 'with cash flows but no measured savings' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:amortization_public).and_return(true)
        CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')
      end

      it 'shows the no-prognosis message' do
        get '/amortization'

        expect(response).to have_http_status(:success)
        expect(response.body).to include('No prognosis possible yet')
      end
    end

    context 'with cash flows but incomplete summaries' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:amortization_public).and_return(true)
        CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')

        allow(Summary).to receive(:missing_or_stale_days).and_return(
          [Date.new(2024, 6, 14)],
        )
      end

      it 'builds the missing summaries first instead of calculating' do
        get '/amortization'

        expect(response).to have_http_status(:success)
        expect(response.body).to include('sequential-frames')
        expect(response.body).not_to include('Nominal balance today')
      end
    end
  end

  describe 'PATCH /amortization' do
    before do
      CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')

      create_summary(
        date: Date.new(2023, 8, 10),
        values: [
          [:house_power, :sum, 10_000],
          [:grid_import_power, :sum, 0],
          [:grid_export_power, :sum, 0],
        ],
      )
    end

    let(:params) do
      { amortization: { period_years: '25', interest_rate: '2.5' } }
    end

    context 'when not logged in' do
      it 'returns http forbidden and keeps the settings' do
        expect do
          patch '/amortization', params: params
        end.not_to change(Setting, :amortization_period_years)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin without sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(false)
        login_as_admin
      end

      it 'returns http forbidden' do
        patch '/amortization', params: params
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin with sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        login_as_admin
      end

      it 'persists the parameters and re-renders the detail' do
        patch '/amortization', params: params

        expect(response).to have_http_status(:success)
        expect(Setting.amortization_period_years).to eq(25)
        expect(Setting.amortization_interest_rate).to eq(2.5)
      end

      it 'clamps values outside the slider range' do
        patch '/amortization',
              params: {
                amortization: {
                  period_years: '999',
                  interest_rate: '-5',
                },
              }

        expect(Setting.amortization_period_years).to eq(
          AmortizationControls::Component::PERIOD_RANGE.max,
        )
        expect(Setting.amortization_interest_rate).to eq(
          AmortizationControls::Component::INTEREST_RANGE.min,
        )
      end
    end
  end
end
