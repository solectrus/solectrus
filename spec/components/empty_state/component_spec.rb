describe EmptyState::Component, type: :component do
  subject(:rendered) { render_inline(described_class.new) }

  it 'renders with empty-state marker class' do
    expect(rendered.css('.empty-state')).to be_present
  end

  it 'renders logo with animation' do
    expect(rendered.css('.logo-glow svg')).to be_present
    expect(rendered.css('.pulse-ring')).to be_present
  end

  it 'renders title' do
    expect(rendered.text).to include('Awaiting sensor data')
  end
end
