describe Flow::Component, type: :component do
  it 'calculates relative height' do
    expect(described_class.new(max: 10_000, value: 0).height).to eq 0
    expect(described_class.new(max: 10_000, value: 100).height).to eq 2
    expect(described_class.new(max: 10_000, value: 200).height).to eq 4
    expect(described_class.new(max: 10_000, value: 2000).height).to eq 32
    expect(described_class.new(max: 10_000, value: 4000).height).to eq 53
    expect(described_class.new(max: 10_000, value: 6000).height).to eq 71
    expect(described_class.new(max: 10_000, value: 9000).height).to eq 93
    expect(described_class.new(max: 10_000, value: 15_000).height).to eq 100
    expect(described_class.new(max: 10_000, value: 30_000).height).to eq 100
  end
end
