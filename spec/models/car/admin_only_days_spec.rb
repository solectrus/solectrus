describe Car::AdminOnlyDays do
  before { travel_to Time.zone.local(2026, 6, 15, 10) }

  it 'covers today and yesterday' do
    expect(%w[day 2026-06-14 2026-06-13].map { described_class.cover?(Timeframe.new(it)) }).to eq([true, true, false])
  end

  it 'ends the data of a visitor with the day before yesterday' do
    expect(described_class.public_timeframe(Timeframe.new('2026-06')).effective_ending_date).to eq(Date.new(2026, 6, 13))
  end

  it 'covers no other period' do
    expect(described_class.cover?(Timeframe.new('2026-06'))).to be(false)
  end
end
