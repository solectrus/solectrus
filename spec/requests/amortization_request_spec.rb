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

        it 'shows the detail view including the parameter sliders' do
          get '/amortization'

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Nominal balance today')
          expect(response.body).to include('amortization-chart--component')
          expect(response.body).to include('type="range"')
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

        it 'does not set a cookie for a visitor using the defaults' do
          get '/amortization'

          expect(response.headers['Set-Cookie'].to_s).not_to include(
            'amortization_params',
          )
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

  describe 'GET /amortization/details' do
    before { allow(Summary).to receive(:missing_or_stale_days).and_return([]) }

    context 'with cash flows and measured savings' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:amortization_public).and_return(true)
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

      it 'renders the yearly table instead of the chart' do
        get '/amortization/details'

        expect(response).to have_http_status(:success)
        # The details view is the table alone - no KPI rail (it stays on the
        # overview), so its heading row can be pinned while the rows scroll.
        expect(response.body).not_to include('Nominal balance today')
        expect(response.body).to include('Earned back')
        # The discounted twin of the nominal balance is its own column.
        expect(response.body).to include('Discounted balance')
        expect(response.body).not_to include('amortization-chart--component')
      end

      it 'offers the sub-navigation with the table tab current' do
        get '/amortization/details'

        expect(response.body).to include('>Progression</span>')
        expect(response.body).to include('>Details</span>')
        expect(response.body).to include('aria-current="location"')
      end

      it 'keeps the cash-flow cells plain for non-admins' do
        # The settings list is admin-only, so a public viewer gets no drill-down.
        get '/amortization/details'

        expect(response.body).not_to include('/settings/cash_flows?')
      end
    end

    context 'when logged in as admin' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        login_as_admin
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

      it 'drills each cash-flow cell down to the filtered settings list' do
        get '/amortization/details'

        aggregate_failures do
          expect(response.body).to include('/settings/cash_flows?')
          # The -50 flow is an investment; the cell links to that category.
          # The filter is multi-select, so the category rides along as category[]
          # (URL-encoded) to match the checkbox form on the settings page.
          expect(response.body).to include('category%5B%5D=investment')
        end
      end
    end

    context 'when not made public and not logged in' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:amortization_public).and_return(false)
        CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')
      end

      it 'hides the calculation like the overview does' do
        get '/amortization/details'

        expect(response).to have_http_status(:success)
        expect(response.body).to include('only visible to administrators')
        expect(response.body).not_to include('Earned back')
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

    context 'when not logged in and not made public' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:amortization_public).and_return(false)
      end

      it 'returns http forbidden' do
        patch '/amortization', params: params
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

    context 'when not logged in, sponsoring active and made public' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:amortization_public).and_return(true)
      end

      it 'recomputes with the given parameters and re-renders the detail' do
        patch '/amortization', params: params

        expect(response).to have_http_status(:success)
        expect(response.body).to include('id="amortization_detail"')
        # The re-rendered sliders reflect the submitted values, nothing is
        # persisted to a global Setting.
        expect(response.body).to include('value="25"')
      end
    end

    context 'when logged in as admin with sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        login_as_admin
      end

      it 'recomputes with the given parameters and re-renders the detail' do
        patch '/amortization', params: params

        expect(response).to have_http_status(:success)
        expect(response.body).to include('value="25"')
      end

      it 're-renders the table when the sliders live on the details view' do
        patch '/amortization', params: params.merge(view: 'details')

        expect(response).to have_http_status(:success)
        expect(response.body).to include('value="25"')
        # The details view re-renders the table, not the chart.
        expect(response.body).to include('Earned back')
        expect(response.body).not_to include('amortization-chart--component')
      end

      it 'remembers the parameters in a single per-browser cookie' do
        patch '/amortization', params: params

        expect(JSON.parse(cookies['amortization_params'])).to eq(
          'period_years' => 25,
          'interest_rate' => 2.5,
        )
      end

      it 'renders a later plain page load from the cookie, not the default' do
        patch '/amortization', params: params

        # No params this time - the value must come from the cookie set above.
        allow(Summary).to receive(:missing_or_stale_days).and_return([])
        get '/amortization'

        expect(response.body).to include('value="25"')
        expect(response.body).not_to include('value="20"')
      end

      it 'refreshes the cookie expiry on a later plain page load' do
        patch '/amortization', params: params

        allow(Summary).to receive(:missing_or_stale_days).and_return([])
        get '/amortization'

        # Sliding expiration: an existing cookie is re-set on every visit.
        expect(response.headers['Set-Cookie'].to_s).to include(
          'amortization_params',
        )
      end

      it 'clamps values outside the slider range before rendering' do
        patch '/amortization',
              params: {
                amortization: {
                  period_years: '999',
                  interest_rate: '-5',
                },
              }

        expect(response).to have_http_status(:success)
        expect(response.body).to include(
          "value=\"#{AmortizationCalculator::PERIOD_RANGE.max}\"",
        )
      end
    end
  end
end
