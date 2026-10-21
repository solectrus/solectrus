describe TimeframePage::Sensor do
  let(:timeframe) { Timeframe.new('2025-03') }

  context 'with the power balance' do
    subject(:page) { described_class.new(namespace: 'balance', sensor_name: 'inverter_power') }

    it 'has no prefix in the address' do
      expect(page.path(timeframe)).to eq('/inverter_power/2025-03')
      expect(page.url_template).to eq('/inverter_power/:timeframe')
    end

    it 'offers the hours' do
      expect(page.offers?(:hours)).to be(true)
    end
  end

  context 'with another home page' do
    subject(:page) { described_class.new(namespace: 'house', sensor_name: 'house_power') }

    it 'has the section in front' do
      expect(page.path(timeframe)).to eq('/house/house_power/2025-03')
      expect(page.url_template).to eq('/house/house_power/:timeframe')
    end
  end

  context 'with the car page and a selected car' do
    subject(:page) { described_class.new(namespace: 'cars', sensor_name: 'car_charging', params: { car: '2' }) }

    it 'keeps the car in each address' do
      expect(page.path(timeframe)).to eq('/cars/2/car_charging/2025-03')
      expect(page.url_template).to eq('/cars/2/car_charging/:timeframe')
    end

    it 'offers no hours' do
      expect(page.offers?(:hours)).to be(false)
    end

    it 'leads not into the forecast' do
      allow(Sensor::Config).to receive(:exists?).and_call_original
      allow(Sensor::Config).to receive(:exists?).with(:inverter_power_forecast).and_return(true)

      expect(page).not_to be_forecast
    end
  end
end
