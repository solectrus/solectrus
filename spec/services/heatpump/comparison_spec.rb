require 'rails_helper'

describe Heatpump::Comparison do
  subject(:comparison) { described_class.new(timeframe, heating:) }

  include_context 'with heat pump comparison'

  let(:timeframe) { Timeframe.new('2025-12-31..2026-01-11') }
  let(:heating) { Heatpump::Heating.new(fuel_type: 'gas', efficiency: 90, fixed_costs: 365) }

  # { fuel type => [[date, price], ...] } in InfluxDB. Gas has a price from
  # January 10, so the last day of December has none.
  let(:prices) { { 'gas' => [[Date.new(2026, 1, 10), 0.10], [Date.new(2026, 1, 11), 0.12]] } }

  before do
    travel_to Date.new(2026, 1, 20).in_time_zone.change(hour: 12)
    [Date.new(2025, 12, 31), Date.new(2026, 1, 10), Date.new(2026, 1, 11)].each { heat_day(it) }
  end

  it 'is ready with a heating, its prices and heat' do
    expect(comparison.state).to be_nil
    expect(comparison).to be_ready
  end

  it 'compares only the days with a fuel price' do
    expect(comparison.days).to eq(2)
    expect(comparison.left_out_days).to eq(1)
    expect(comparison.heat_wh).to eq(18_000)
    expect(comparison.power_wh).to eq(6_000)
    expect(comparison.cop).to eq(3)
  end

  # 10 kWh of gas a day at 0.10 and 0.12 EUR
  it 'burns the fuel for the heat at the price of each day' do
    expect(comparison.fuel_wh).to be_within(0.01).of(20_000)
    expect(comparison.fuel_cost).to be_within(0.0001).of(2.2)
  end

  it 'gives the prices from the first to the last compared day' do
    expect(comparison.compared_dates).to eq(Date.new(2026, 1, 10)..Date.new(2026, 1, 11))
    expect(comparison.fuel_series).to eq([[Date.new(2026, 1, 10), 0.10], [Date.new(2026, 1, 11), 0.12]])
    expect(comparison.fuel_price_extremes).to eq([[Date.new(2026, 1, 10), 0.10], [Date.new(2026, 1, 11), 0.12]])
  end

  it 'adds the fixed costs of each compared day' do
    expect(comparison.fixed_cost).to be_within(0.0001).of(2.0)
    expect(comparison.heating_cost).to be_within(0.0001).of(4.2)
  end

  # Grid energy at the electricity price, PV energy at the feed-in price
  it 'gives the costs of the heat pump with and without the PV system' do
    electricity = Price.at(name: :electricity, date: Date.new(2026, 1, 10)).to_f
    feed_in = Price.at(name: :feed_in, date: Date.new(2026, 1, 10)).to_f

    expect(comparison.cost).to be_within(0.0001).of((electricity + (feed_in * 2)) * 2)
    expect(comparison.cost_without_pv).to be_within(0.0001).of(2 * 3 * electricity)
  end

  # The amounts in cents add up, so the savings are the rounded costs
  # less the rounded costs of the heat pump
  it 'gives the savings as the page shows them' do
    amounts = Heatpump::ComparisonAmounts.new(comparison)

    expect(amounts.precision).to eq(2)
    expect(amounts.heating_cost).to eq(4.2)
    expect(amounts.heatpump_cost).to eq(0.84)
    expect(amounts.without_pv_cost).to eq(1.53)
    expect(amounts.savings).to be_within(0.001).of(3.36)
    expect(amounts.savings_without_pv).to be_within(0.001).of(2.67)
  end

  # 365 EUR a year is 1 EUR for each of the two compared days of 2026
  context 'with payments' do
    before do
      Heatpump::Payment.create!(category: :operating_costs, date: Date.new(2026, 1, 1), amount: 365)
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 3, 1), amount: 730)
      Heatpump::Payment.create!(category: :purchase, date: Date.new(2026, 1, 5), amount: 20_000)
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2024, 3, 1), amount: 999)
    end

    it 'counts the running costs of the year for each compared day' do
      expect(comparison.payment_costs.transform_values { it.round(4) }).to eq('operating_costs' => 2.0, 'maintenance' => 4.0)
    end

    # Each side has its own running costs, so the payments add to the heat
    # pump alone
    it 'adds the payments to the costs of the heat pump' do
      expect(comparison.total_cost).to be_within(0.0001).of(comparison.cost + 6)
      expect(comparison.total_cost_without_pv).to be_within(0.0001).of(comparison.cost_without_pv + 6)
      expect(comparison.heating_cost).to be_within(0.0001).of(comparison.fuel_cost + comparison.fixed_cost)
    end

    it 'shares the payments with the periods of a split' do
      expect(comparison.split(:month).to_h { |dates, period| [dates.begin, period.payments.round(4)] }).to eq(Date.new(2026, 1, 1) => 6.0)
    end
  end

  # The heat pump starts on January 10, so 2026 has 356 days of it. A
  # payment of that year belongs to these days alone, while the running
  # costs of the heating count a 365th for each day.
  context 'when the heat pump starts in the year' do
    let(:timeframe) { Timeframe.new('2026-01-10..2026-01-11') }

    before do
      SummaryValue.where(date: Date.new(2025, 12, 31)).delete_all
      Heatpump::Payment.create!(category: :operating_costs, date: Date.new(2026, 5, 1), amount: 356)
    end

    it 'spreads the payments of the year over the days of the heat pump' do
      expect(comparison.payment_costs.transform_values { it.round(4) }).to eq('operating_costs' => 2.0)
      expect(comparison.fixed_cost).to be_within(0.0001).of(2.0)
    end
  end

  context 'with heating oil' do
    let(:heating) { Heatpump::Heating.new(fuel_type: 'heating_oil', efficiency: 90) }
    let(:prices) { { 'heating_oil' => [[Date.new(2025, 12, 1), 1.06]] } }

    # 30 kWh of fuel for 27 kWh of heat, 10.6 kWh a liter
    it 'buys liters' do
      expect(comparison.days).to eq(3)
      expect(comparison.fuel_units).to be_within(0.0001).of(30.0 / 10.6)
      expect(comparison.fuel_cost).to be_within(0.0001).of(3.0)
      expect(comparison.fixed_cost).to eq(0)
    end
  end

  context 'without a heating' do
    let(:heating) { Heatpump::Heating.new(efficiency: 90) }

    it { expect(comparison.state).to eq(:none) }
  end

  context 'without the prices of the fuel' do
    let(:prices) { {} }

    it { expect(comparison.state).to eq(:no_prices) }
    it { expect(comparison.fuel_series).to eq([]) }
  end

  context 'without heat in the timeframe' do
    let(:timeframe) { Timeframe.new('2025-11') }

    it { expect(comparison.state).to eq(:no_heat) }
  end

  describe '.available?' do
    subject(:available) { described_class.available?(heating) }

    it 'is true with the sensors and the prices of one fuel' do
      expect(available).to be(true)
    end

    it 'asks only for the prices of the fuel of the heating' do
      available

      expect(Sensor::Query::FuelPrices).to have_received(:new).with('gas').once
      expect(Sensor::Query::FuelPrices).not_to have_received(:new).with('heating_oil')
    end

    # The admin can pick heating oil then
    context 'with the prices of another fuel only' do
      let(:prices) { { 'heating_oil' => [[Date.new(2026, 1, 5), 1.0]] } }

      it { is_expected.to be(true) }
    end

    context 'without a heating' do
      let(:heating) { Heatpump::Heating.new }

      it { is_expected.to be(true) }
    end

    context 'without the prices of any fuel' do
      let(:prices) { {} }

      it { is_expected.to be(false) }
    end
  end
end
