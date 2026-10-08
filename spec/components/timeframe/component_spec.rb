describe Timeframe::Component, type: :component do
  subject(:component) { described_class.new(timeframe: Timeframe.new(period)) }

  around { |example| I18n.with_locale(:de) { example.run } }

  context 'with a day' do
    let(:period) { '2026-09-25' }

    it 'names the day and needs no dates' do
      expect(component.period_name).to eq('Freitag, 25. September 2026')
      expect(component.period_dates).to be_nil
    end
  end

  # A phone hides these dates in the navigation, the bottom sheet shows them
  context 'with a week' do
    let(:period) { '2026-W39' }

    it 'names the week and its first and last day' do
      expect(component.period_name).to eq('KW 39, 2026')
      expect(component.period_dates).to eq('21.09.2026 – 27.09.2026')
    end
  end
end
