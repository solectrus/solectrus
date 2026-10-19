require 'rails_helper'

describe CashFlow::Filter do
  def filter(params) = described_class.from_params(params)

  it 'takes categories and dates' do
    expect(filter(category: %w[investment repair], from: '2025-01-01', to: '2025-12-31')).to have_attributes(
      categories: %w[investment repair], from: Date.new(2025, 1, 1), to: Date.new(2025, 12, 31),
    )
  end

  it 'leaves out what does not fit' do
    expect(filter(category: 'unknown', from: 'nonsense')).not_to be_active
  end

  it 'narrows to a category, and keeps the dates' do
    narrowed = filter(category: %w[investment repair], from: '2025-01-01').with_category('repair')

    expect(narrowed.to_params).to eq(category: %w[repair], from: '2025-01-01')
  end

  it 'narrows to the year of a date, and keeps the categories' do
    narrowed = filter(category: 'repair').with_year(Date.new(2025, 4, 1))

    aggregate_failures do
      expect(narrowed.to_params).to eq(category: %w[repair], from: '2025-01-01', to: '2025-12-31')
      expect(narrowed.year).to eq(2025)
      expect(filter(from: '2025-04-01', to: '2026-03-31').year).to be_nil
    end
  end

  it 'leaves out a category or the dates, and keeps the rest' do
    full = filter(category: %w[investment repair], from: '2025-01-01', to: '2025-12-31')

    aggregate_failures do
      expect(full.without_category('repair').to_params).to eq(category: %w[investment], from: '2025-01-01', to: '2025-12-31')
      expect(full.without_dates.to_params).to eq(category: %w[investment repair])
    end
  end

  it 'gives a new cash flow the first category' do
    expect(filter(category: %w[repair investment]).category).to eq('repair')
    expect(filter({}).category).to be_nil
  end

  it 'filters the cash flows' do
    CashFlow.create!(category: :repair, date: Date.new(2025, 4, 1), amount: -800, note: 'Inverter')
    CashFlow.create!(category: :repair, date: Date.new(2024, 4, 1), amount: -700, note: 'Cable')
    CashFlow.create!(category: :investment, date: Date.new(2025, 3, 1), amount: -5000, note: 'Panels')

    expect(filter(category: 'repair', from: '2025-01-01').apply(CashFlow.all).map(&:amount)).to eq([-800])
  end
end
