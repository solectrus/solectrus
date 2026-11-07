describe Sensor::Query::FuelPrices do
  subject(:prices) { described_class.new('petrol').call }

  context 'without any data' do
    it { is_expected.to eq([]) }
  end

  context 'without a fuel' do
    subject(:prices) { described_class.new(nil).call }

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

  # The price of natural gas has a measurement of its own, one value a month
  context 'with the prices of natural gas' do
    subject(:prices) { described_class.new('gas').call }

    before do
      influx_batch do
        add_influx_point(name: 'Gas', fields: { price: 0.12 }, time: Time.zone.local(2026, 2, 1))
        add_influx_point(name: 'Fuel', fields: { price_heating_oil: 1.05 }, time: Time.zone.local(2026, 2, 2))
      end
    end

    it 'gives the prices of the gas' do
      expect(prices).to eq([[Date.new(2026, 2, 1), 0.12]])
    end
  end
end
