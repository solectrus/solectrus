describe ConicGradient do
  it 'puts the parts one after another, from the top' do
    expect(described_class.css([['red', 25], ['green', 75]])).to eq('conic-gradient(red 0% 25%, green 25% 100%)')
  end

  it 'rounds the stops' do
    expect(described_class.css([['red', 33.3333], ['green', 66.6667]])).to eq('conic-gradient(red 0% 33.33%, green 33.33% 100.0%)')
  end
end
