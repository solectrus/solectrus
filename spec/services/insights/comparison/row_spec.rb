describe Insights::Comparison::Row do
  def row(more_is_better) = described_class.new(key: :total, unit: :watt, base: 100, current: 120, more_is_better:)

  it 'rates the change by the direction that is better' do
    expect(row(true).rating).to eq(:better)
    expect(row(false).rating).to eq(:worse)
  end

  it 'rates the change of a neutral sensor neither way' do
    expect(row(nil).rating).to eq(:neutral)
  end

  it 'rates no change as the same' do
    expect(described_class.new(key: :total, unit: :watt, base: 100, current: 100, more_is_better: true).rating).to eq(:same)
  end

  it 'has no rating without the earlier value' do
    expect(described_class.new(key: :total, unit: :watt, base: nil, current: 100, more_is_better: true).rating).to be_nil
  end
end
