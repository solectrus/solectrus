describe Ui::YearGroups do
  def rows(*days) = days.map { Struct.new(:date).new(Date.iso8601(it)) }

  it 'gives a header to each new year' do
    groups = described_class.new(rows('2026-03-20', '2026-01-02', '2025-12-27'))

    expect(groups.map(&:last)).to eq([2026, nil, 2025])
  end

  it 'gives no second header to a year that goes on from the page before' do
    groups = described_class.new(rows('2026-03-02', '2025-12-27'), previous_date: Date.new(2026, 5, 1))

    expect(groups.map(&:last)).to eq([nil, 2025])
  end
end
