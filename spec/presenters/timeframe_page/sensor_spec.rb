describe TimeframePage::Sensor do
  let(:timeframe) { Timeframe.new('2025-03') }

  context 'with the power balance' do
    subject(:page) { described_class.new(namespace: 'balance', sensor_name: 'inverter_power') }

    it 'has no prefix in the address' do
      expect(page.path(timeframe)).to eq('/inverter_power/2025-03')
      expect(page.base_url).to eq('/inverter_power')
    end

    it 'offers the hours' do
      expect(page).to be_hours
    end
  end

  context 'with another home page' do
    subject(:page) { described_class.new(namespace: 'house', sensor_name: 'house_power') }

    it 'has the section in front' do
      expect(page.path(timeframe)).to eq('/house/house_power/2025-03')
      expect(page.base_url).to eq('/house/house_power')
    end
  end

  context 'with the car page and a selected car' do
    subject(:page) { described_class.new(namespace: 'cars', sensor_name: 'car_charging', params: { car: '2' }) }

    it 'keeps the car in each address' do
      expect(page.path(timeframe)).to eq('/cars/2/car_charging/2025-03')
      expect(page.base_url).to eq('/cars/2/car_charging')
    end

    it 'offers no hours' do
      expect(page).not_to be_hours
    end
  end
end
