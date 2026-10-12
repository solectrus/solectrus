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

  context 'without a value' do
    let(:value) { nil }

    it 'shows six inactive boxes' do
      expect(html.css('span.font-mono').map { it.text.strip }).to eq(%w[– – – – – –])
      expect(html.css('span.font-mono.bg-slate-100')).to be_present
    end
  end
end
