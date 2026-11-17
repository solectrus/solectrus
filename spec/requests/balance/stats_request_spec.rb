describe 'Stats' do
  describe 'GET /stats' do
    it_behaves_like 'localized request', '/stats/house_power/now'
    it_behaves_like 'sponsoring redirects', '/stats/house_power/now'

    context 'with turbo_frame request' do
      it 'renders' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response).to have_http_status(:ok)
      end
    end

    # The content of the two status frames: in the bar and on the page
    def status_templates
      %w[balance-status-now balance-status-content-now].map do |target|
        response.body[%r{<turbo-stream action="update" target="#{target}"><template>(.*?)</template>}m, 1]
      end
    end

    context 'with a current power reading' do
      before do
        add_influx_point(name: Sensor::Config.measurement(:house_power), fields: { Sensor::Config.field(:house_power) => 500 })
      end

      it 'shows the status' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(status_templates).to all(include('<time'))
      end
    end

    # NoCurrentReading::Component tells the time of the last reading instead
    context 'without a current power reading' do
      it 'clears the status' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response.body).to include('No current readings')
        expect(status_templates).to all(be_empty)
      end
    end

    context 'with the home battery and one car in use' do
      before do
        Car.create!(id: 1)
        add_influx_point(name: Sensor::Config.measurement(:battery_soc), fields: { Sensor::Config.field(:battery_soc) => 64 })
        add_influx_point(name: Sensor::Config.measurement(:car_battery_soc_1), fields: { Sensor::Config.field(:car_battery_soc_1) => 78 })
        # Without a current power reading, now shows no bars
        add_influx_point(name: Sensor::Config.measurement(:house_power), fields: { Sensor::Config.field(:house_power) => 500 })
      end

      it 'shows the state of charge of both' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response.body).to include('soc-badge', '64%', '78%', balance_charts_path(sensor_name: 'car_battery_soc_1', timeframe: 'now'))
      end
    end

    # Without inverter_as_total the balance shows each inverter instead of
    # the sum
    context 'with each inverter in the balance' do
      before do
        Setting.inverter_as_total = false
        create_summary(
          date: Date.new(2025, 5, 10),
          values: [
            [:inverter_power, :sum, 3000.0],
            [:inverter_power_1, :sum, 2000.0],
            [:inverter_power_2, :sum, 1000.0],
          ],
        )

        # Without a current reading, now shows no bars
        %i[inverter_power_1 inverter_power_2].each do |sensor_name|
          add_influx_point(name: Sensor::Config.measurement(sensor_name), fields: { Sensor::Config.field(sensor_name) => 1000 })
        end
      end

      %w[now 2025].each do |timeframe|
        it "shows the inverters of #{timeframe}" do
          get balance_stats_path(sensor_name: 'house_power', timeframe:),
              headers: {
                'Turbo-Frame' => 'random-turbo-frame',
              }

          expect(response.body).to include(
            balance_charts_path(sensor_name: 'inverter_power_1', timeframe:),
            balance_charts_path(sensor_name: 'inverter_power_2', timeframe:),
          )
        end
      end
    end

    # A consumer outside the house power has a segment of its own
    context 'with a consumer excluded from the house power' do
      include_context 'with an excluded custom consumer'

      before do
        create_summary(
          date: Date.new(2025, 5, 10),
          values: [[:custom_power_01, :sum, 500.0]],
        )
      end

      it 'shows the consumer beside the house' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: '2025'),
            headers: {
              'Turbo-Frame' => 'random-turbo-frame',
            }

        expect(response.body).to include(
          balance_charts_path(sensor_name: 'custom_power_01', timeframe: '2025'),
        )
      end
    end

    context 'with default request' do
      it 'redirects' do
        get balance_stats_path(sensor_name: 'house_power', timeframe: 'now')

        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
