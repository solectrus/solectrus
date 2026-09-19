describe 'Home' do
  describe 'GET /' do
    it_behaves_like 'localized request', '/'
    it_behaves_like 'sponsoring redirects', '/'

    context 'without params :fields and :timeframe' do
      it 'redirects to power balance' do
        get balance_home_path
        expect(response).to redirect_to(
          balance_home_path(sensor_name: 'power_balance', timeframe: 'now'),
        )
      end

      context 'when power balance chart is not available' do
        before do
          allow(ApplicationPolicy).to receive(:power_balance_chart?).and_return(false)
        end

        context 'when day' do
          before do
            allow(Sensor::Query::DayLight).to receive(:active?).and_return(true)
          end

          it 'redirects to inverter power' do
            get balance_home_path
            expect(response).to redirect_to(
              balance_home_path(sensor_name: 'inverter_power', timeframe: 'now'),
            )
          end
        end

        context 'when night' do
          before do
            allow(Sensor::Query::DayLight).to receive(:active?).and_return(false)
          end

          it 'redirects to house power' do
            get balance_home_path
            expect(response).to redirect_to(
              balance_home_path(sensor_name: 'house_power', timeframe: 'now'),
            )
          end
        end
      end
    end

    context 'without param :timeframe' do
      it 'redirects' do
        get balance_home_path(sensor_name: 'house_power')
        expect(response).to redirect_to(
          balance_home_path(sensor_name: 'house_power', timeframe: 'now'),
        )
      end
    end

    context 'with params :sensor and :timeframe' do
      it 'renders' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: Date.yesterday.strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end
    end

    context 'when param :timeframe is in the future' do
      it 'redirects to forecast for day' do
        get balance_home_path(
              timeframe: (Date.current + 2.days).strftime('%Y-%m-%d'),
              sensor_name: 'inverter_power',
            )
        expect(response).to redirect_to(forecast_path)
      end

      it 'redirects to forecast for week' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: (Date.current + 1.week).strftime('%G-W%V'),
            )
        expect(response).to redirect_to(forecast_path)
      end

      it 'redirects to forecast for month' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: (Date.current + 1.month).strftime('%Y-%m'),
            )
        expect(response).to redirect_to(forecast_path)
      end

      it 'redirects to forecast for year' do
        get balance_home_path(
              sensor_name: 'inverter_power',
              timeframe: (Date.current + 1.year).strftime('%Y'),
            )
        expect(response).to redirect_to(forecast_path)
      end
    end

    context 'when timeframe is before installation date' do
      it 'renders for day' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.day
                ).strftime('%Y-%m-%d'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for week' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.week
                ).strftime('%Y-W%V'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for month' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.month
                ).strftime('%Y-%m'),
            )
        expect(response).to have_http_status(:ok)
      end

      it 'renders for year' do
        get balance_home_path(
              sensor_name: 'house_power',
              timeframe:
                (
                  Rails.configuration.x.installation_date.beginning_of_year -
                    1.year
                ).strftime('%Y'),
            )
        expect(response).to have_http_status(:ok)
      end
    end

    # Clicking a tab again used to walk through the readings of its period,
    # and nothing announced that. The current tab carries them as a menu.
    context 'with the menu of the current timeframe' do
      before do
        allow(Sensor).to receive(:data?).and_return(true)
        allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
      end

      def menu_entries
        menu = response.body[%r{<div class="relative flex-1.*?</div>\s*</div>}m]

        menu
          .to_s
          .scan(%r{<a[^>]*class="([^"]*)"[^>]*role="menuitem"[^>]*>([^<]*)</a>})
          .map { |classes, name| { name: name.strip, classes: } }
      end

      def menu_names = menu_entries.pluck(:name)

      it 'offers this month and the last 30 days' do
        get balance_home_path(sensor_name: 'house_power', timeframe: 'month')

        expect(menu_names).to eq(
          [I18n.t('timeframe.month'), I18n.t('timeframe.days', count: 30)],
        )
      end

      # The same menu wherever it was opened from, so it does not reorder
      # itself as the reading changes.
      it 'reads the same from the rolling window' do
        get balance_home_path(sensor_name: 'house_power', timeframe: 'P30D')

        expect(menu_names).to eq(
          [I18n.t('timeframe.month'), I18n.t('timeframe.days', count: 30)],
        )
      end

      it 'offers all three readings of a year' do
        get balance_home_path(sensor_name: 'house_power', timeframe: 'year')

        expect(menu_names).to eq(
          [I18n.t('timeframe.year'), I18n.t('timeframe.months', count: 12), I18n.t('timeframe.days', count: 365)],
        )
      end

      # A month that is over has no "last 30 days" of its own, so the readings
      # below it are the ones that are running. It stands above them and says
      # where the page is before it offers the ways on.
      it 'offers the ways on from a period of the past' do
        get balance_home_path(sensor_name: 'house_power', timeframe: '2024-03')

        expect(menu_names).to eq(
          [Timeframe.new('2024-03').localized, I18n.t('timeframe.month'), I18n.t('timeframe.days', count: 30)],
        )
      end
    end
  end
end
