describe Sensor::Definitions::CaseTemp do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:instance) { described_class.new }

  describe '#allowed_aggregations' do
    subject { instance.allowed_aggregations }

    it { is_expected.to eq([:avg]) }
  end
end
