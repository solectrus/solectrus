describe 'Settings heat pump payments' do
  it 'forbids the list to a visitor' do
    get settings_heatpump_payments_path

    expect(response).to have_http_status(:forbidden)
  end

  context 'when logged in as admin' do
    # The payments need the prices of the comparison, which the test
    # InfluxDB lacks
    before do
      login_as_admin
      allow(Heatpump::Comparison).to receive(:available?).and_return(true)
    end

    it 'leads to the settings without prices' do
      allow(Heatpump::Comparison).to receive(:available?).and_return(false)

      get settings_heatpump_payments_path

      expect(response).to redirect_to(settings_path)
    end

    it 'lists the payments of the heat pump alone, an income positive and an expense negative' do
      Heatpump::Payment.create!(category: :subsidy, date: Date.new(2024, 5, 1), amount: 3000, note: 'BAFA')
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2024, 6, 1), amount: 150, note: 'Service')
      Car.configured.first.payments.create!(category: :ghg_quota, date: Date.new(2024, 5, 1), amount: 350, note: 'GHG quota')

      get settings_heatpump_payments_path

      text = response.parsed_body.text.squish
      expect(text).to include('BAFA', 'Service', 'Maintenance')
      expect(text).not_to include('GHG quota')
      expect(response.parsed_body.css('.text-signal-negative').map { it.text.squish }).to eq(['-€150.00'])
    end

    it 'introduces the payments without one' do
      get settings_heatpump_payments_path

      expect(response.body).to include('No payments yet')
    end

    it 'adds a payment' do
      post settings_heatpump_payments_path, params: { heatpump_payment: { category: 'operating_costs', date: '2024-01-01', amount: '120', note: 'Meter' } }

      expect(Heatpump::Payment.sole).to have_attributes(category: 'operating_costs', date: Date.new(2024, 1, 1), amount: 120, note: 'Meter')
    end

    it 'refuses a category of a car' do
      post settings_heatpump_payments_path, params: { heatpump_payment: { category: 'ghg_quota', date: '2024-01-01', amount: '120' } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(Heatpump::Payment.count).to eq(0)
    end

    it 'changes and deletes a payment' do
      payment = Heatpump::Payment.create!(category: :maintenance, date: Date.new(2024, 6, 1), amount: 150)

      patch settings_heatpump_payment_path(payment), params: { heatpump_payment: { amount: '180' } }
      expect(payment.reload.amount).to eq(180)

      delete settings_heatpump_payment_path(payment)
      expect(Heatpump::Payment.count).to eq(0)
    end

    it 'loads the next page into its frame' do
      26.times { Heatpump::Payment.create!(category: :maintenance, date: Date.new(2025, 1, 1) + it, amount: 5) }

      get settings_heatpump_payments_path
      expect(response.body).to include('id="heatpump_payments_page_2"')

      get settings_heatpump_payments_path(page: 2), headers: { 'Turbo-Frame' => 'heatpump_payments_page_2' }
      expect(response.body).to include('<turbo-frame', 'id="heatpump_payments_page_2"')
      expect(response.body).not_to include('heatpump_payments_page_3')
    end

    it 'refreshes the list after a save in the modal' do
      post settings_heatpump_payments_path,
           params: { heatpump_payment: { category: 'maintenance', date: '2025-03-01', amount: '150', note: 'Service 2025' } },
           headers: { 'Turbo-Frame' => 'modal' },
           as: :turbo_stream

      expect(response.body).to include('<turbo-stream action="update" target="list">', 'Service 2025')
    end

    it 'is a tab beside the heating' do
      get edit_settings_heatpump_path

      expect(response.parsed_body.css("a[href='#{settings_heatpump_payments_path}']")).to be_present
    end
  end
end
