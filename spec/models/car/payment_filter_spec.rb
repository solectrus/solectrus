require 'rails_helper'

describe Car::PaymentFilter do
  let(:car) { Car.create!(id: 1, active_from: Date.new(2024, 1, 1)) }

  def filter(params) = described_class.from_params(params, cars: [car])

  it 'takes a car, categories and dates' do
    expect(filter(car: '1', category: %w[insurance maintenance], from: '2025-01-01', to: '2025-12-31')).to have_attributes(
      car:, categories: %w[insurance maintenance], from: Date.new(2025, 1, 1), to: Date.new(2025, 12, 31), year: 2025,
    )
  end

  it 'leaves out what does not fit' do
    expect(filter(car: '2', category: 'unknown', from: 'nonsense')).not_to be_active
  end

  it 'narrows to the year of a date, and keeps the rest' do
    narrowed = filter(category: 'maintenance').with_year(Date.new(2025, 4, 1))

    expect(narrowed.to_params).to eq(category: %w[maintenance], from: '2025-01-01', to: '2025-12-31')
  end

  it 'leaves out the car, a category or the dates, and keeps the rest' do
    full = filter(car: '1', category: %w[insurance maintenance], from: '2025-01-01', to: '2025-12-31')

    aggregate_failures do
      expect(full.without_car.to_params).to eq(category: %w[insurance maintenance], from: '2025-01-01', to: '2025-12-31')
      expect(full.without_category('insurance').to_params).to eq(car: 1, category: %w[maintenance], from: '2025-01-01', to: '2025-12-31')
      expect(full.without_dates.to_params).to eq(car: 1, category: %w[insurance maintenance])
    end
  end

  it 'gives a new payment its single category' do
    expect(filter(category: 'maintenance').category).to eq('maintenance')
    expect(filter(category: %w[maintenance insurance]).category).to be_nil
  end

  it 'filters the payments' do
    car.payments.create!(category: :maintenance, date: Date.new(2025, 4, 1), amount: 800)
    car.payments.create!(category: :maintenance, date: Date.new(2024, 4, 1), amount: 700)
    car.payments.create!(category: :insurance, date: Date.new(2025, 3, 1), amount: 500)

    expect(filter(category: 'maintenance', from: '2025-01-01').apply(Car::Payment.all).map(&:amount)).to eq([800])
  end
end
