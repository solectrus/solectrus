describe TimeframePage::Sensor do
  let(:timeframe) { Timeframe.new('2025-03') }

  context 'with the power balance' do
    subject(:page) { described_class.new(namespace: 'balance', sensor_name: 'inverter_power') }

    it 'has no prefix in the address' do
      expect(page.path(timeframe)).to eq('/inverter_power/2025-03')
      expect(page.base_url).to eq('/inverter_power')
    end
  end

  context 'with another home page' do
    subject(:page) { described_class.new(namespace: 'house', sensor_name: 'house_power') }

    it 'has the section in front' do
      expect(page.path(timeframe)).to eq('/house/house_power/2025-03')
      expect(page.base_url).to eq('/house/house_power')
    end
  end
end
