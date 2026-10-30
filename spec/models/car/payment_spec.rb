require 'rails_helper'

# == Schema Information
#
# Table name: car_payments
#
#  id         :bigint           not null, primary key
#  amount     :decimal(10, 2)   not null
#  category   :string           not null
#  date       :date             not null
#  note       :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  car_id     :integer          not null
#
# Indexes
#
#  index_car_payments_on_car_id  (car_id)
#
# Foreign Keys
#
#  fk_rails_...  (car_id => cars.id)
#
describe Car::Payment do
  let(:car) { Car.create!(id: 1, active_from: Date.new(2025, 1, 1), active_until: Date.new(2025, 12, 31)) }

  def payment(category, date = Date.new(2025, 6, 1)) = described_class.new(car:, category:, date:, amount: 100)

  it 'needs a category' do
    expect(payment(nil)).not_to be_valid
  end

  # The list shows the configured cars only
  it 'needs a configured car' do
    other = Car.create!(id: 2, active_from: Date.new(2025, 1, 1))

    expect(described_class.new(car: other, category: :insurance, date: Date.new(2025, 6, 1), amount: 100)).not_to be_valid
  end

  it 'takes its direction from its category' do
    expect(payment(:ghg_quota).signed_amount).to eq(100)
    expect(payment(:insurance).signed_amount).to eq(-100)
  end

  # A refund lowers the cost of its category, for example of the insurance
  it 'takes a negative amount as a refund of an expense' do
    refund = described_class.new(car:, category: :insurance, date: Date.new(2025, 6, 1), amount: -4)

    expect(refund).to be_valid
    expect(refund.signed_amount).to eq(4)
    expect(described_class.new(car:, category: :ghg_quota, date: Date.new(2025, 6, 1), amount: -4)).not_to be_valid
    expect(described_class.new(car:, category: :insurance, date: Date.new(2025, 6, 1), amount: 0)).not_to be_valid
  end

  it 'counts in the comparison without buying, financing and selling' do
    %i[ghg_quota vehicle_tax charging_fees insurance purchase leasing_rate loan_rate subsidy sale].each { payment(it).save! }

    expect(described_class.compared.map(&:category)).to contain_exactly('ghg_quota', 'vehicle_tax', 'charging_fees', 'insurance')
  end

  it 'falls in the period of use of its car' do
    expect(payment(:insurance, Date.new(2026, 1, 1))).not_to be_valid
    expect(payment(:insurance, Date.new(2025, 12, 31))).to be_valid
  end

  # The car and the down payment of a lease are paid before it comes, and
  # the subsidy and the sale come after. A rate falls in the period.
  it 'can lie outside the period of use for buying and selling' do
    expect(payment(:purchase, Date.new(2024, 11, 1))).to be_valid
    expect(payment(:leasing_down_payment, Date.new(2024, 11, 1))).to be_valid
    expect(payment(:leasing_rate, Date.new(2024, 12, 1))).not_to be_valid
    expect(payment(:subsidy, Date.new(2026, 2, 1))).to be_valid
    expect(payment(:sale, Date.new(2026, 1, 15))).to be_valid
  end
end
