describe Place::ListBox::Component, type: :component do
  subject(:text) do
    render_inline(
      described_class.new(
        list:,
        counts: { visits: 3, places: 2 },
        segments: [],
        map_path: '/cars/places/map',
        component: Ui::EmptyState::Component.new(icon: 'list', title: 'The list'),
        timeframe: Timeframe.new('2026-06'),
      ),
    ).text.squish
  end

  context 'with the places' do
    let(:list) { 'places' }

    it 'counts the places' do
      expect(text).to include('2 places')
    end
  end

  context 'with the visits' do
    let(:list) { 'visits' }

    it 'counts the visits and their places' do
      expect(text).to include('3 visits at 2 places')
    end
  end
end
