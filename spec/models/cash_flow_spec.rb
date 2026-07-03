# == Schema Information
#
# Table name: cash_flows
#
#  id         :bigint           not null, primary key
#  amount     :decimal(10, 2)   not null
#  date       :date             not null
#  note       :string           not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_cash_flows_on_date  (date)
#
describe CashFlow do
  describe 'database' do
    it do
      is_expected.to have_db_column(:date).of_type(:date).with_options(
        null: false,
      )
    end

    it do
      is_expected.to have_db_column(:amount).of_type(:decimal).with_options(
        precision: 10,
        scale: 2,
        null: false,
      )
    end

    it do
      is_expected.to have_db_column(:note).of_type(:string).with_options(
        null: false,
      )
    end

    it { is_expected.to have_db_index(:date) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:date) }
    it { is_expected.to validate_presence_of(:note) }
    it { is_expected.to validate_presence_of(:amount) }

    it 'rejects a zero amount' do
      cash_flow = described_class.new(date: Date.current, note: 'Test', amount: 0)

      expect(cash_flow).not_to be_valid
      expect(cash_flow.errors[:amount]).to be_present
    end

    it 'allows negative and positive amounts' do
      expect(
        described_class.new(date: Date.current, note: 'Cost', amount: -500),
      ).to be_valid

      expect(
        described_class.new(date: Date.current, note: 'Revenue', amount: 500),
      ).to be_valid
    end
  end

  describe '.ordered' do
    it 'sorts by date descending' do
      older = described_class.create!(date: 1.year.ago, amount: -100, note: 'Old')
      newer = described_class.create!(date: Date.current, amount: -100, note: 'New')

      expect(described_class.ordered).to eq([newer, older])
    end
  end
end
