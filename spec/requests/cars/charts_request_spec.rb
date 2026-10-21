describe 'Car Charts' do
  describe 'GET /cars/charts' do
    {
      'car_consumption_rate' => %w[2026-W30 2026-06 2026 all],
      'car_cost_rate' => %w[2026-W30 2026-06 2026 all],
      'car_driving_costs' => %w[2026-W30 2026-06 2026 all],
    }.each do |sensor_name, timeframes|
      timeframes.each do |timeframe|
        context "with #{sensor_name} and timeframe #{timeframe}" do
          it 'renders' do
            get cars_charts_path(sensor_name:, timeframe:),
                headers: {
                  'Turbo-Frame' => 'random-turbo-frame',
                }

            expect(response).to have_http_status(:ok)
          end
        end
      end
    end

    context 'with the distance of a day' do
      let(:headers) { { 'Turbo-Frame' => 'random-turbo-frame' } }
      let(:path) { cars_charts_path(sensor_name: 'car_distance', timeframe: Date.yesterday.iso8601) }

      before do
        Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'))
        influx_batch do
          [[Date.yesterday.in_time_zone.change(hour: 8), 1000], [Date.yesterday.in_time_zone.change(hour: 10), 1010]].each do |time, value|
            add_influx_point(name: 'Trabant', fields: { odometer: value.to_f }, time:)
          end
        end
        place = Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Garage')
        PlaceVisit.create!(date: Date.yesterday, car: Car.configured.first, place:, started_at: Date.yesterday.beginning_of_day, ended_at: Date.yesterday.beginning_of_day + 9.hours)
      end

      after { Sensor::Config.setup(ENV) }

      it 'shows the places in the tooltip to the admin only' do
        get(path, headers:)
        expect(response).to have_http_status(:ok)
        # The guest gets the line of the car, without its places
        expect(response.body).to include('car_odometer_1')
        expect(response.body).not_to include('Garage')

        login_as_admin
        get(path, headers:)
        expect(response.body).to include('Garage')
      end

      # The stats keep the toggle, so the chart sets it
      it 'renders the toggle of a phone for the card of the chart' do
        get(path, headers:)

        html = Nokogiri::HTML4(response.body) # rubocop:disable Rails/ResponseParsedBody
        expect(html.at_css("turbo-stream[target='cars-car-card-toggle-#{Date.yesterday.iso8601}'] [aria-pressed=true]")['data-car-cards-card-param'])
          .to eq('driving')
      end
    end
  end
end
