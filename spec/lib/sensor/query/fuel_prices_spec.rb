describe Sensor::Query::FuelPrices do
  subject(:prices) { described_class.new('petrol').call }

  context 'without any data' do
    it { is_expected.to eq([]) }
  end

  # The collector writes each price at the local midnight of a Monday
  context 'with the prices of the collector' do
    before do
      influx_batch do
        add_influx_point(name: 'Fuel', fields: { price_petrol: 1.80, price_diesel: 1.60 }, time: Time.zone.local(2026, 1, 12))
        add_influx_point(name: 'Fuel', fields: { price_petrol: 1.70, price_diesel: 1.50 }, time: Time.zone.local(2026, 1, 5))
      end
    end

    it 'gives the prices of the fuel, sorted by date' do
      expect(prices).to eq([[Date.new(2026, 1, 5), 1.70], [Date.new(2026, 1, 12), 1.80]])
    end
  end
end
