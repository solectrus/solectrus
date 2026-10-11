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

  describe 'a change of a price' do
    let!(:first) { described_class.electricity.create!(starts_at: Date.new(2026, 1, 1), value: 0.30) }
    let!(:second) { described_class.electricity.create!(starts_at: Date.new(2026, 4, 1), value: 0.32) }

    before do
      described_class.where.not(id: [first.id, second.id]).delete_all
      [Date.new(2026, 1, 1), Date.new(2026, 3, 31), Date.new(2026, 4, 1)].each do |date|
        start = date.in_time_zone.change(hour: 10)
        ChargingSession.create!(kind: 'wallbox', origin: 'detection', started_at: start, ended_at: start + 2.hours, kwh: 10, cost: 3.0)
      end
    end

    def costs = ChargingSession.order(:started_at).pluck(:cost).map(&:to_f)

    it 'prices the sessions of the price again' do
      first.update!(value: 0.31)

      expect(costs).to eq([3.1, 3.1, 3.0])
    end

    it 'prices the sessions up to today for the last price' do
      second.update!(value: 0.33)

      expect(costs).to eq([3.0, 3.0, 3.3])
    end

    it 'prices the sessions of the old and of the new start' do
      second.update!(starts_at: Date.new(2026, 3, 31))

      expect(costs).to eq([3.0, 3.2, 3.2])
    end

    it 'prices the sessions of a removed price with the price before' do
      second.destroy!

      expect(costs).to eq([3.0, 3.0, 3.0])
    end

    it 'keeps the cost for a new note' do
      first.update!(note: 'Tariff')

      expect(costs).to eq([3.0, 3.0, 3.0])
    end

    it 'leaves an offsite session alone' do
      car = Car.create!(id: 1, short_name: '1', active_from: Date.new(2025, 1, 1))
      offsite = ChargingSession.create!(kind: 'offsite', origin: 'user', car:, started_at: Time.zone.local(2026, 2, 1, 10), kwh: 10, cost: 5.0)

      first.update!(value: 0.31)

      expect(offsite.reload.cost).to eq(5.0)
    end
  end

  describe '.seed!' do
    before { described_class.delete_all }

    it 'creates electricity and feed_in prices' do
      expect { described_class.seed! }.to change(described_class, :count).by(2)

      expect(described_class.electricity.first).to have_attributes(
        starts_at: Rails.configuration.x.installation_date,
        value: 0.2545,
      )
      expect(described_class.feed_in.first).to have_attributes(
        starts_at: Rails.configuration.x.installation_date,
        value: 0.0832,
      )
    end

    context 'when prices already exist' do
      before { described_class.seed! }

      it 'does not create duplicates or raise' do
        expect { described_class.seed! }.not_to change(described_class, :count)
      end
    end
  end
end
