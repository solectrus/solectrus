describe 'Settings car payments' do
  let(:car) { Car.configured.first }

  it 'forbids the list to a visitor' do
    get settings_car_payments_path

    expect(response).to have_http_status(:forbidden)
  end

  context 'when logged in as admin' do
    # The payments need the fuel prices of the comparison, which the test
    # InfluxDB lacks
    before do
      login_as_admin
      allow(Car::Comparison).to receive(:available?).and_return(true)
    end

    it 'leads to the cars without fuel prices' do
      allow(Car::Comparison).to receive(:available?).and_return(false)

      get settings_car_payments_path

      expect(response).to redirect_to(settings_cars_path)
    end

    it 'lists the payments with their category, an income positive and an expense negative' do
      car.payments.create!(category: :ghg_quota, date: Date.new(2024, 5, 1), amount: 350, note: 'GHG quota')
      car.payments.create!(category: :maintenance, date: Date.new(2024, 6, 1), amount: 50, note: 'Wallbox repair')

      get settings_car_payments_path

      expect(response.parsed_body.text.squish).to include('GHG quota', 'Wallbox repair', 'Maintenance')
      expect(response.parsed_body.css('.text-signal-positive').map { it.text.squish }).to eq(['€ 350.00', '€ 300.00'])
      expect(response.parsed_body.css('.text-signal-negative').map { it.text.squish }).to eq(['-€50.00'])
    end

    it 'introduces the payments without one' do
      get settings_car_payments_path

      expect(response.body).to include('No payments yet')
    end

    it 'adds a payment' do
      post settings_car_payments_path, params: { car_payment: { car_id: car.id, category: 'ghg_quota', date: '2024-05-01', amount: '350', note: 'GHG quota' } }

      expect(car.payments.sole).to have_attributes(category: 'ghg_quota', date: Date.new(2024, 5, 1), amount: 350, note: 'GHG quota')
    end

    it 'refuses a payment without an amount' do
      post settings_car_payments_path, params: { car_payment: { car_id: car.id, category: 'ghg_quota', date: '2024-05-01', amount: '' } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(Car::Payment.count).to eq(0)
    end

    it 'changes a payment' do
      payment = car.payments.create!(category: :ghg_quota, date: Date.new(2024, 5, 1), amount: 350)

      patch settings_car_payment_path(payment), params: { car_payment: { category: 'maintenance', amount: '40' } }

      expect(payment.reload).to have_attributes(category: 'maintenance', amount: 40)
    end

    it 'refuses a payment outside the period of use of the car' do
      car.update!(active_from: Date.new(2025, 1, 1))

      post settings_car_payments_path, params: { car_payment: { car_id: car.id, category: 'insurance', date: '2024-12-31', amount: '500' } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('is not in the period of use of the car')
    end

    it 'filters the list by category and year, with a notice and the total of the filter' do
      car.payments.create!(category: :insurance, date: Date.new(2024, 3, 1), amount: 500, note: 'Insurance 2024')
      car.payments.create!(category: :insurance, date: Date.new(2025, 3, 1), amount: 520, note: 'Insurance 2025')
      car.payments.create!(category: :maintenance, date: Date.new(2025, 4, 1), amount: 800, note: 'Inspection 2025')

      get settings_car_payments_path(category: 'insurance', from: '2025-01-01', to: '2025-12-31')

      expect(response.parsed_body.css('[aria-label="Filtered by"]')).to be_present
      expect(response.parsed_body.text.squish).to include('Insurance 2025')
      expect(response.parsed_body.text.squish).not_to include('Insurance 2024', 'Inspection 2025')
      expect(response.parsed_body.css('.text-signal-negative').map { it.text.squish }).to eq(['-€520.00', '-€520.00'])
      expect(response.parsed_body.css('h3.ui-group-header')).to be_empty
    end

    it 'removes a single part of the filter with the x of its pill' do
      car.payments.create!(category: :insurance, date: Date.new(2025, 3, 1), amount: 520)

      get settings_car_payments_path(car: car.id, category: %w[insurance maintenance], from: '2025-01-01', to: '2025-12-31')

      expect(response.parsed_body.css('a[aria-label="Remove from filter"]').pluck('href')).to eq(
        [
          '/settings/car_payments?category%5B%5D=insurance&category%5B%5D=maintenance&from=2025-01-01&to=2025-12-31',
          "/settings/car_payments?car=#{car.id}&category%5B%5D=maintenance&from=2025-01-01&to=2025-12-31",
          "/settings/car_payments?car=#{car.id}&category%5B%5D=insurance&from=2025-01-01&to=2025-12-31",
          "/settings/car_payments?car=#{car.id}&category%5B%5D=insurance&category%5B%5D=maintenance",
        ],
      )
    end

    it 'offers a chevron to narrow the list to the year and the category of a row' do
      car.payments.create!(category: :maintenance, date: Date.new(2025, 4, 1), amount: 800)

      get settings_car_payments_path

      expect(response.parsed_body.css('a').pluck('href')).to include(
        '/settings/car_payments?from=2025-01-01&to=2025-12-31',
        '/settings/car_payments?category%5B%5D=maintenance',
      )
    end

    it 'ignores a filter that does not fit' do
      car.payments.create!(category: :maintenance, date: Date.new(2025, 4, 1), amount: 800, note: 'Inspection 2025')

      get settings_car_payments_path(category: 'unknown', car: 99, from: 'nonsense')

      expect(response.parsed_body.text.squish).to include('Inspection 2025')
      expect(response.parsed_body.css('[aria-label="Filtered by"]')).to be_empty
    end

    # The total is the sum of all 26 payments, not of the first page
    it 'loads the next page into its frame' do
      26.times { car.payments.create!(category: :maintenance, date: Date.new(2025, 1, 1) + it, amount: 5) }

      get settings_car_payments_path

      expect(response.body).to include('id="car_payments_page_2"')
      expect(response.parsed_body.css('.text-signal-negative').last.text.squish).to eq('-€130.00')

      get settings_car_payments_path(page: 2), headers: { 'Turbo-Frame' => 'car_payments_page_2' }

      expect(response.body).to include('<turbo-frame', 'id="car_payments_page_2"')
      expect(response.body).not_to include('car_payments_page_3')
    end

    # 25 payments of 2025 fill the first page, so 2024 starts the second one.
    # A year that goes on from the page before has no second header.
    it 'names each year once, also across the pages' do
      26.times { car.payments.create!(category: :maintenance, date: Date.new(2025, 1, 1) + it, amount: 5) }
      car.payments.create!(category: :maintenance, date: Date.new(2024, 12, 31), amount: 5)

      get settings_car_payments_path

      expect(response.parsed_body.css('h3.ui-group-header').map(&:text)).to eq(['2025'])

      get settings_car_payments_path(page: 2), headers: { 'Turbo-Frame' => 'car_payments_page_2' }

      expect(response.parsed_body.css('h3.ui-group-header').map(&:text)).to eq(['2024'])
    end

    it 'gives a new payment the category of the filter' do
      get new_settings_car_payment_path(return_to: settings_car_payments_path(category: 'leasing_rate'))

      expect(response.parsed_body.at_css('select[name="car_payment[category]"] option[selected]')['value']).to eq('leasing_rate')
    end

    it 'refreshes the filtered list after a save in the form that it opened' do
      car.payments.create!(category: :maintenance, date: Date.new(2025, 4, 1), amount: 800, note: 'Inspection 2025')

      post settings_car_payments_path,
           params: {
             car_payment: { car_id: car.id, category: 'insurance', date: '2025-03-01', amount: '520', note: 'Insurance 2025' },
             return_to: settings_car_payments_path(category: 'insurance'),
           },
           headers: { 'Turbo-Frame' => 'modal' },
           as: :turbo_stream

      expect(response.body).to include('<turbo-stream action="update" target="list">', 'Insurance 2025')
      expect(response.body).not_to include('Inspection 2025')
    end

    it 'deletes a payment' do
      payment = car.payments.create!(category: :maintenance, date: Date.new(2024, 5, 1), amount: 50)

      delete settings_car_payment_path(payment)

      expect(Car::Payment.count).to eq(0)
    end
  end
end
