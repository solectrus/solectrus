require 'rails_helper'

describe Car::FuelPrices do
  subject(:prices) { described_class.new('petrol') }

  let(:points) { [[Date.new(2026, 1, 5), 1.70], [Date.new(2026, 1, 12), 1.80]] }
  let(:query) { instance_double(Sensor::Query::FuelPrices, call: points) }

  before { allow(Sensor::Query::FuelPrices).to receive(:new).with('petrol').and_return(query) }

  # A price of the collector starts at the local midnight of a Monday
  it 'gives the price of the week of a date, and the last price after it' do
    expect(prices.at(Date.new(2026, 1, 5))).to eq(1.70)
    expect(prices.at(Date.new(2026, 1, 11))).to eq(1.70)
    expect(prices.at(Date.new(2026, 1, 12))).to eq(1.80)
    expect(prices.at(Date.new(2026, 9, 1))).to eq(1.80)
  end

  it 'gives no price before the first one' do
    expect(prices.at(Date.new(2026, 1, 4))).to be_nil
  end

  # The price of the first date, each new price, and the price of the last
  # date close the stepped line
  it 'gives the series of the dates for a stepped line' do
    expect(prices.series(Date.new(2026, 1, 8)..Date.new(2026, 1, 31))).to eq(
      [[Date.new(2026, 1, 8), 1.70], [Date.new(2026, 1, 12), 1.80], [Date.new(2026, 1, 31), 1.80]],
    )
  end

  it 'starts the series at the first price' do
    expect(prices.series(Date.new(2026, 1, 1)..Date.new(2026, 1, 10))).to eq(
      [[Date.new(2026, 1, 5), 1.70], [Date.new(2026, 1, 10), 1.70]],
    )
  end

  describe '.any?' do
    let(:diesel) { instance_double(Sensor::Query::FuelPrices, call: []) }

    before { allow(Sensor::Query::FuelPrices).to receive(:new).with('diesel').and_return(diesel) }

    it 'is true with the prices of one fuel' do
      expect(described_class).to be_any
    end

    context 'without prices of any fuel' do
      let(:points) { [] }

      it 'is false' do
        expect(described_class).not_to be_any
      end
    end
  end

  # The electricity prices are in the currency of the installation
  context 'with another currency' do
    before { allow(Currency).to receive(:eur?).and_return(false) }

    it 'has none and does not ask InfluxDB' do
      expect(prices.any?).to be(false)
      expect(described_class).not_to be_any
      expect(Sensor::Query::FuelPrices).not_to have_received(:new)
    end
  end

  context 'without prices' do
    let(:points) { [] }

    it 'has none' do
      expect(prices.any?).to be(false)
      expect(prices.at(Date.new(2026, 1, 5))).to be_nil
    end

    # The collector can start later, so the empty result holds for a short
    # time only
    it 'asks InfluxDB again after a few minutes' do
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      2.times { described_class.new('petrol').any? }
      travel 6.minutes
      described_class.new('petrol').any?

      expect(query).to have_received(:call).twice
    end
  end
end
