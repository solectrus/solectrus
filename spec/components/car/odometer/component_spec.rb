describe Car::Odometer::Component, type: :component do
  subject(:component) { described_class.new(value:) }

  let(:html) { render_inline(component) }

  context 'with less than six digits' do
    let(:value) { 64_800.4 }

    it 'fills up the six digits with zeros' do
      expect(html.css('span.font-mono').map { it.text.strip }).to eq(%w[0 6 4 8 0 0])
    end
  end

  context 'with more than six digits' do
    let(:value) { 1_234_567 }

    it 'shows each digit' do
      expect(html.css('span.font-mono').size).to eq(7)
    end
  end

  context 'when compact' do
    subject(:component) { described_class.new(value: 64_800, compact: true) }

    it 'shows narrower boxes in the same color' do
      expect(html.css('span.font-mono.w-\[1\.375rem\].bg-slate-500').size).to eq(6)
    end
  end

  context 'with a path' do
    subject(:component) { described_class.new(value: 64_800, path: '/distance') }

    it 'links the digits' do
      expect(html.css('a[href="/distance"] span.font-mono').size).to eq(6)
    end

    it 'names the link with the reading' do
      expect(html.at_css('a[href="/distance"]')['aria-label']).to eq('Odometer 64,800 km')
    end
  end

  context 'without a path' do
    let(:value) { 64_800 }

    it 'links nowhere' do
      expect(html.css('a')).to be_empty
    end
  end

  context 'without a value' do
    let(:value) { nil }

    it 'shows six inactive boxes' do
      expect(html.css('span.font-mono').map { it.text.strip }).to eq(%w[– – – – – –])
      expect(html.css('span.font-mono.bg-slate-100')).to be_present
    end
  end
end
