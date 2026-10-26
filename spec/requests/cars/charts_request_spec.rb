describe 'Car Charts' do
  describe 'GET /cars/charts' do
    {
      'car_consumption_rate' => %w[2026-W30 2026-06 2026 all],
      'car_cost_rate' => %w[2026-W30 2026-06 2026 all],
      'car_driving_costs' => %w[2026-W30 2026-06 2026 all],
      'car_driving_energy' => %w[2026-W30 2026-06 2026 all],
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

    # A day has the timeline of the day in place of the charts
    it 'sends a day to its overview' do
      get cars_charts_path(sensor_name: 'car_distance', timeframe: '2026-06-26'), headers: { 'Turbo-Frame' => 'random-turbo-frame' }

      expect(response).to redirect_to('/cars/2026-06-26')
    end
  end
end
