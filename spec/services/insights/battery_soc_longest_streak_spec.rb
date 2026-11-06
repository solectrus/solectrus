describe Insights::BatterySocLongestStreak do
  subject(:streak) { described_class.new(timeframe:).call }

  let(:timeframe) { Timeframe.new('2025-10') }

  def create_min_soc(day, value)
    create_summary(date: Date.new(2025, 10, day), values: [[:battery_soc, :min, value]])
  end

  context 'with days on which the battery never ran empty' do
    before do
      create_min_soc(1, 10)
      create_min_soc(2, 0)
      create_min_soc(3, 15)
      create_min_soc(4, 20)
      create_min_soc(5, 5)
      create_min_soc(6, 0)
    end

    it 'is the longest run of such days' do
      expect(streak).to eq(from: Date.new(2025, 10, 3), to: Date.new(2025, 10, 5), length: 3)
    end
  end

  context 'when the battery ran empty every day' do
    before do
      create_min_soc(1, 0)
      create_min_soc(2, 0)
    end

    it 'has no streak' do
      expect(streak).to eq(from: nil, to: nil, length: 0)
    end
  end
end
