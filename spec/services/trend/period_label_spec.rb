describe Trend::PeriodLabel do
  def label(string) = described_class.new(Timeframe.new(string)).to_s

  before { travel_to Date.new(2026, 11, 20) }

  it 'names a month short' do
    expect(label('2025-11')).to eq('Nov 2025')
  end

  it 'names the days of one month' do
    expect(label('2025-11-01..2025-11-20')).to eq('Nov 1–20, 2025')
  end

  it 'names the days of one year' do
    expect(label('2025-01-01..2025-11-20')).to eq('Jan 1 – Nov 20, 2025')
  end

  # Days of two years have no short form
  it 'names days of two years as the timeframe does' do
    timeframe = Timeframe.new('2024-12-01..2025-01-31')

    expect(described_class.new(timeframe).to_s).to eq(timeframe.localized)
  end
end
