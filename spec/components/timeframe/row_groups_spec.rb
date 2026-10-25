describe Timeframe::RowGroups do
  def rows(*days) = days.map { Struct.new(:started_at).new(Time.zone.parse("#{it} 10:00")) }

  it 'groups the rows of a month by week, with a header for each new week' do
    groups = described_class.new(rows('2026-03-02', '2026-03-03', '2026-03-10'), timeframe: Timeframe.new('2026-03'))

    expect(groups.map { |_row, group| group&.to_s }).to eq(['2026-W10', nil, '2026-W11'])
  end

  it 'gives no second header to a group that goes on from the page before' do
    groups = described_class.new(rows('2026-03-03'), timeframe: Timeframe.new('2026-03'), previous_started_at: Time.zone.parse('2026-03-02 10:00'))

    expect(groups.map(&:last)).to eq([nil])
  end

  it 'names a day by its weekday' do
    groups = described_class.new(rows('2026-03-02'), timeframe: Timeframe.new('2026-03-02'))
    group = groups.first.last

    expect(groups.title(group)).to eq(I18n.l(Date.new(2026, 3, 2), format: '%A'))
  end
end
