describe Battery::Component, type: :component do
  before { render_inline(described_class.new(fuel_charge:, temperature:)) }

  let(:fuel_charge) { 10 }
  let(:temperature) { 25 }

  it 'renders percentage' do
    expect(page).to have_text('10 %')
  end

  context 'when the temperature is low' do
    let(:temperature) { 12 }

    it 'renders blue text' do
      expect(page).to have_css('.text-blue-600')
      expect(page).to have_text('12 °C')
    end
  end

  context 'when the temperature is medium' do
    let(:temperature) { 30 }

    it 'renders green text' do
      expect(page).to have_css('.text-green-600')
      expect(page).to have_text('30 °C')
    end
  end

  context 'when the temperature is high' do
    let(:temperature) { 50 }

    it 'renders red text' do
      expect(page).to have_css('.text-red-600')
      expect(page).to have_text('50 °C')
    end
  end
end
