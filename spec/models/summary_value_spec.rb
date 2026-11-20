# == Schema Information
#
# Table name: summary_values
#
#  aggregation :enum             not null, primary key
#  date        :date             not null, primary key
#  field       :enum             not null, primary key
#  value       :float            not null
#
# Indexes
#
#  index_summary_values_on_field_and_aggregation_and_date  (field,aggregation,date)
#
# Foreign Keys
#
#  fk_rails_...  (date => summaries.date) ON DELETE => cascade
#

describe SummaryValue do
  describe 'auto-generated enums from Sensor::Definitions' do
    describe 'field enum' do
      it 'only includes sensors with summary_aggregations' do
        described_class.fields.each_key do |field_name|
          sensor_name = field_name.to_sym
          sensor = Sensor::Registry[sensor_name]

          expect(sensor.summary_aggregations).not_to be_empty,
          "Sensor #{sensor_name} should have summary_aggregations but has: #{sensor.summary_aggregations}"
        end
      end
    end

    describe 'aggregation enum' do
      it 'includes all aggregation types' do
        actual_aggregations = described_class.aggregations.keys

        expect(actual_aggregations).to match_array(%w[sum max min avg last])
      end
    end
  end

  describe 'validations' do
    subject { described_class.new }

    it { is_expected.to validate_presence_of(:field) }
    it { is_expected.to validate_presence_of(:aggregation) }
    it { is_expected.to validate_presence_of(:value) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:summary) }
  end

  describe '.first_dates' do
    before do
      create_summary(date: Date.new(2025, 1, 1), values: [[:inverter_power, :sum, 1_000]])
      create_summary(date: Date.new(2025, 2, 1), values: [[:inverter_power, :sum, 1_000], [:house_power, :sum, 1_000]])
    end

    it 'finds the first day of each field' do
      expect(described_class.first_dates(%i[inverter_power house_power wallbox_power])).to eq(
        'inverter_power' => Date.new(2025, 1, 1),
        'house_power' => Date.new(2025, 2, 1),
      )
    end

    it 'finds nothing without a field' do
      expect(described_class.first_dates([])).to eq({})
    end
  end
end
