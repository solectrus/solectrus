# == Schema Information
#
# Table name: prices
#
#  id         :bigint           not null, primary key
#  name       :string           not null
#  note       :string
#  starts_at  :date             not null
#  value      :decimal(8, 5)    not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_prices_on_name_and_starts_at  (name,starts_at) UNIQUE
#
describe Price do
  describe 'database' do
    it do
      is_expected.to have_db_column(:name).of_type(:string).with_options(
        null: false,
      )
    end

    it do
      is_expected.to have_db_column(:starts_at).of_type(:date).with_options(
        null: false,
      )
    end

    it do
      is_expected.to have_db_column(:value).of_type(:decimal).with_options(
        precision: 8,
        scale: 5,
        null: false,
      )
    end
  end

  describe 'enums' do
    it do
      is_expected.to define_enum_for(:name).with_values(
        electricity: 'electricity',
        feed_in: 'feed_in',
      ).backed_by_column_of_type(:string)
    end
  end

  describe 'validations' do
    subject do
      described_class.electricity.new(value: 0.30, starts_at: Date.current)
    end

    before { described_class.delete_all }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:starts_at) }
    it { is_expected.to validate_presence_of(:value) }

    it do
      is_expected.to validate_numericality_of(
        :value,
      ).is_greater_than_or_equal_to(0)
    end

    it { is_expected.to validate_uniqueness_of(:starts_at).scoped_to(:name) }
  end

  describe '#destroyable?' do
    subject { price.destroyable? }

    let!(:price) do
      described_class.electricity.create!(value: 0.30, starts_at: 3.years.ago)
    end

    context 'when there are no other prices' do
      it { is_expected.to be false }
    end

    context 'when there are other prices with different name' do
      before do
        described_class.feed_in.create! value: 0.08, starts_at: Date.current
      end

      it { is_expected.to be false }
    end

    context 'when there are other prices with same name' do
      before do
        described_class.electricity.create! value: 0.32, starts_at: Date.current
      end

      it { is_expected.to be true }
    end
  end
end
