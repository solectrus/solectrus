require 'rails_helper'

describe Heatpump::Savings do
  subject(:amounts) { described_class.new(timeframe, heating:).amounts }

  include_context 'with heat pump comparison'

  let(:timeframe) { Timeframe.new('2026-01') }
  let(:heating) { Heatpump::Heating.new(fuel_type: 'gas', efficiency: 90, fixed_costs: 365) }
  let(:prices) { { 'gas' => [[Date.new(2026, 1, 1), 0.10]] } }
  let(:comparison) { instance_double(Heatpump::Comparison, ready?: true) }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    travel_to Date.new(2026, 1, 20).in_time_zone.change(hour: 12)
    create_summary(date: Date.new(2026, 1, 10))
    allow(Heatpump::Comparison).to receive(:new).and_return(comparison)
    allow(Heatpump::ComparisonAmounts).to receive(:new).with(comparison).and_return(
      instance_double(Heatpump::ComparisonAmounts, precision: 2, heating_cost: 4.25, heatpump_cost: 1.5),
    )
  end

  it 'gives the amounts of the page' do
    expect(amounts).to have_attributes(precision: 2, heating_cost: 4.25, heatpump_cost: 1.5, savings: 2.75)
  end

  it 'reads the amounts from the cache the next time' do
    2.times { described_class.new(timeframe, heating:).amounts }

    expect(Heatpump::Comparison).to have_received(:new).once
  end

  context 'without a heating' do
    let(:heating) { Heatpump::Heating.new(efficiency: 90) }

    it { is_expected.to be_nil }
  end

  describe 'a change of an input' do
    before { described_class.new(timeframe, heating:).amounts }

    it 'calculates again with a new payment' do
      Heatpump::Payment.create!(category: :maintenance, date: Date.new(2026, 1, 5), amount: 31)

      amounts
      expect(Heatpump::Comparison).to have_received(:new).twice
    end

    it 'calculates again with a new day of the timeframe' do
      create_summary(date: Date.new(2026, 1, 11))

      amounts
      expect(Heatpump::Comparison).to have_received(:new).twice
    end

    it 'calculates again with another heating' do
      described_class.new(timeframe, heating: heating.dup.tap { it.efficiency = 80 }).amounts

      expect(Heatpump::Comparison).to have_received(:new).twice
    end

    it 'calculates again with a corrected fuel price' do
      prices['gas'] = [[Date.new(2026, 1, 1), 0.11]]
      Rails.cache.delete(%w[fuel-prices gas])

      described_class.new(timeframe, heating: Heatpump::Heating.new(fuel_type: 'gas', efficiency: 90, fixed_costs: 365)).amounts
      expect(Heatpump::Comparison).to have_received(:new).twice
    end

    it 'keeps the amounts of another timeframe' do
      create_summary(date: Date.new(2026, 2, 1))

      amounts
      expect(Heatpump::Comparison).to have_received(:new).once
    end
  end
end
