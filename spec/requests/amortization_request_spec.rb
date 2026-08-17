describe 'Amortization' do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Date.new(2024, 6, 15)

    # Runs transactional, so this does not affect the suite-wide seed data
    # created for system tests (which may exist when suites run together)
    Summary.delete_all
  end

  # The page shell leaves the calculation to a Turbo frame that fetches it
  # separately, so anything computed lives behind this request, not behind the
  # page URL.
  def get_content(view: nil)
    get '/amortization/content',
        params: {
          view:,
        }.compact,
        headers: {
          'Turbo-Frame' => 'amortization_detail',
        }
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

        it 'links to the same page on the demo installation' do
          get '/amortization'

          expect(response.body).to include(
            'https://demo.solectrus.de/amortization',
          )
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

        it 'shows the shell with the parameter sliders and the detail frame' do
          get '/amortization'

          aggregate_failures do
            expect(response).to have_http_status(:success)
            expect(response.body).to include('type="range"')
            # Not cached (null store in test), so the frame fetches it
            expect(response.body).to include('src="/amortization/content')
            expect(response.body).not_to include('amortization-chart--component')
          end
        end

        it 'renders an already cached calculation with the shell' do
          # Nothing to wait for, so the frame is filled right away instead of
          # fetching itself.
          allow(AmortizationCalculator).to receive(:cached_result).and_return(
            AmortizationCalculator.new.result,
          )

          get '/amortization'

          aggregate_failures do
            expect(response).to have_http_status(:success)
            expect(response.body).to include('amortization-chart--component')
            expect(response.body).not_to include('src="/amortization/content')
          end
        end

        it 'shows the calculation in the detail frame' do
          get_content

          aggregate_failures do
            expect(response).to have_http_status(:success)
            expect(response.body).to include('Undiscounted balance today')
            expect(response.body).to include('amortization-chart--component')
          end
        end

        it 'offers the cash-flow settings shortcut to non-admins too' do
          # The cog icon links everyone to the settings; a non-admin clicking it
          # lands on the admin-required hint.
          get '/amortization'

          expect(response.body).to include('Manage cash flows')
          expect(response.body).to include('/settings/cash_flows')
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
            'Only visible to administrators',
          )
          expect(response.body).not_to include('Undiscounted balance today')
        end

        it 'shows no sub-navigation, sliders or settings shortcut' do
          # Nothing is computed for a viewer who may not see the calculation, so
          # the sub-navigation (tabs, parameter sliders, settings cog) is absent.
          get '/amortization'

          expect(response.body).not_to include('amortization[period_years]')
          expect(response.body).not_to include('/settings/cash_flows')
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
          expect(response.body).not_to include('Undiscounted balance today')
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

          get_content

          expect(response).to have_http_status(:success)
          expect(response.body).to include('Undiscounted balance today')
          expect(response.body).to include('amortization-chart--component')
        end

        it 'renders the parameter sliders next to the detail frame' do
          # The sliders sit in the sub-navigation, outside the frame, so they
          # come with the shell and stay put while the calculation is fetched.
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

      context 'when disabled entirely (visibility "none")' do
        before do
          allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
          allow(Setting).to receive(:enable_amortization).and_return(false)
          login_as_admin
        end

        it 'responds with 404, even for an admin' do
          get '/amortization'

          expect(response).to have_http_status(:not_found)
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
        get_content

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
        get_content

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).to include('sequential-frames')
          expect(response.body).not_to include('Undiscounted balance today')
        end
      end

      it 'hides the sub-navigation until the summaries are complete' do
        get '/amortization'

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).not_to include('type="range"')
        end
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
        get_content(view: 'details')

        expect(response).to have_http_status(:success)
        # The details view is the table alone - no KPI rail (it stays on the
        # overview), so its heading row can be pinned while the rows scroll.
        expect(response.body).not_to include('Undiscounted balance today')
        expect(response.body).to include('Earned back')
        # The discounted twin of the nominal balance is its own column.
        expect(response.body).to include('Discounted balance')
        expect(response.body).not_to include('amortization-chart--component')
      end

      it 'offers the sub-navigation with the table tab current' do
        get '/amortization/details'

        expect(response.body).to include('>Balance</span>')
        expect(response.body).to include('>Details</span>')
        expect(response.body).to include('aria-current="location"')
      end

      it 'drills the cash-flow cells down for non-admins too' do
        # The drill-down link is offered to every viewer of the table; the
        # settings page requires admin, so a non-admin clicking it lands on the
        # admin-required hint.
        get_content(view: 'details')

        expect(response.body).to include('/settings/cash_flows?')
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
        get_content(view: 'details')

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
        expect(response.body).to include('Only visible to administrators')
        expect(response.body).not_to include('Earned back')
      end
    end
  end

  describe 'GET /amortization/returns' do
    before do
      allow(Summary).to receive(:missing_or_stale_days).and_return([])
      allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
      allow(Setting).to receive(:amortization_public).and_return(true)
      CashFlow.create!(date: Date.new(2021, 7, 10), amount: -300, note: 'PV')
    end

    def seed_savings_day(date)
      create_summary(
        date:,
        values: [
          [:house_power, :sum, 10_000],
          [:grid_import_power, :sum, 0],
          [:grid_export_power, :sum, 0],
        ],
      )
    end

    context 'with more than a year of measured savings' do
      before do
        36.times { |index| seed_savings_day(Date.new(2021, 7, 10) + index.months) }
      end

      it 'renders the return history chart instead of the balance chart' do
        get_content(view: 'returns')

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).to include(
            'amortization-return-chart--component',
          )
          expect(response.body).not_to include('amortization-chart--component')
        end
      end

      it 'offers the sub-navigation with the return tab current' do
        get '/amortization/returns'

        aggregate_failures do
          expect(response.body).to include('>Balance</span>')
          expect(response.body).to include('>Return</span>')
          expect(response.body).to include('aria-current="location"')
        end
      end
    end

    context 'with less than a year of measured savings' do
      before { seed_savings_day(Date.new(2024, 6, 10)) }

      it 'shows a hint instead of an empty chart' do
        get_content(view: 'returns')

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).to include('No history available yet')
          expect(response.body).not_to include(
            'amortization-return-chart--component',
          )
        end
      end
    end

    context 'when the first year completes on this very day' do
      before do
        # measured_days counts inclusively, so day 365 is installation + 364:
        # the first evaluable date and today are the same, leaving a single
        # sample - not enough for a curve.
        date = Date.current - 364
        while date <= Date.current
          seed_savings_day(date)
          date += 30
        end
      end

      it 'shows the hint rather than a chart with a lone point' do
        get_content(view: 'returns')

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).to include('No history available yet')
          expect(response.body).not_to include(
            'amortization-return-chart--component',
          )
        end
      end
    end
  end

  describe 'GET /amortization/content' do
    before do
      allow(Summary).to receive(:missing_or_stale_days).and_return([])
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

    it 'renders the calculation into the detail frame' do
      get_content

      aggregate_failures do
        expect(response).to have_http_status(:success)
        expect(response.body).to include('id="amortization_detail"')
        expect(response.body).to include('amortization-chart--component')
      end
    end

    it 'redirects a plain request to the page it belongs to' do
      # Nothing to show on its own - the fragment only makes sense inside the
      # page shell.
      get '/amortization/content', params: { view: 'details' }

      expect(response).to redirect_to('/amortization/details')
    end

    context 'when the calculation is not visible' do
      before do
        allow(Setting).to receive(:amortization_public).and_return(false)
      end

      it 'returns http forbidden' do
        get_content

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when disabled entirely (visibility "none")' do
      before do
        allow(Setting).to receive(:enable_amortization).and_return(false)
        login_as_admin
      end

      it 'responds with 404, even for an admin' do
        get_content

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PATCH /amortization' do
    # The sliders are only on screen once the summaries are complete, and the
    # recomputation checks that again before it runs.
    before do
      allow(Summary).to receive(:missing_or_stale_days).and_return([])

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

    context 'when disabled entirely (visibility "none")' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        allow(Setting).to receive(:enable_amortization).and_return(false)
        login_as_admin
      end

      it 'returns 404 before recomputing' do
        patch '/amortization', params: params
        expect(response).to have_http_status(:not_found)
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
        allow(AmortizationCalculator).to receive(:result).and_call_original

        patch '/amortization', params: params

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).to include('id="amortization_detail"')
          # Recomputed with the submitted values, nothing is persisted to a
          # global Setting.
          expect(AmortizationCalculator).to have_received(:result).with(
            period_years: 25,
            interest_rate: 2.5,
          )
        end
      end
    end

    context 'when logged in as admin with sponsoring' do
      before do
        allow(ApplicationPolicy).to receive(:amortization?).and_return(true)
        login_as_admin
      end

      it 'recomputes with the given parameters and re-renders the detail' do
        allow(AmortizationCalculator).to receive(:result).and_call_original

        patch '/amortization', params: params

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).to include('amortization-chart--component')
          expect(AmortizationCalculator).to have_received(:result).with(
            period_years: 25,
            interest_rate: 2.5,
          )
        end
      end

      it 're-renders the table when the sliders live on the details view' do
        patch '/amortization', params: params.merge(view: 'details')

        expect(response).to have_http_status(:success)
        # The details view re-renders the table, not the chart.
        expect(response.body).to include('Earned back')
        expect(response.body).not_to include('amortization-chart--component')
      end

      it 're-renders the return history when the sliders live on that view' do
        patch '/amortization', params: params.merge(view: 'returns')

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(response.body).not_to include('amortization-chart--component')
        end
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
        get '/amortization'

        expect(response.body).to include('value="25"')
        expect(response.body).not_to include('value="20"')
      end

      it 'refreshes the cookie expiry on a later plain page load' do
        patch '/amortization', params: params

        get '/amortization'

        # Sliding expiration: an existing cookie is re-set on every visit.
        expect(response.headers['Set-Cookie'].to_s).to include(
          'amortization_params',
        )
      end

      it 'clamps values outside the slider range before rendering' do
        allow(AmortizationCalculator).to receive(:result).and_call_original

        patch '/amortization',
              params: {
                amortization: {
                  period_years: '999',
                  interest_rate: '-5',
                },
              }

        aggregate_failures do
          expect(response).to have_http_status(:success)
          expect(AmortizationCalculator).to have_received(:result).with(
            period_years: AmortizationCalculator::PERIOD_RANGE.max,
            interest_rate: AmortizationCalculator::INTEREST_RANGE.min,
          )
        end
      end
    end
  end
end
