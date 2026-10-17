describe Car::Map::Component, type: :component do
  let(:cars) { [{ places: [[50.9, 14.1, 1]] }] }
  let(:root) { render_inline(component).at_css('[data-controller="car--map--component"]') }

  context 'when movable' do
    subject(:component) { described_class.new(cars:, movable: true) }

    it 'is a live map whose point the user moves, with the texts of its hint and its button' do
      expect(root['data-car--map--component-live-value']).to eq('true')
      expect(JSON.parse(root['data-car--map--component-movable-value'])).to eq(
        'hint' => 'Drag the point or tap the map',
        'station' => 'Use the charging station “{name}”',
        'unnamedStation' => 'Use the charging station',
      )
    end
  end

  context 'when not movable' do
    subject(:component) { described_class.new(cars:, live: true) }

    it 'keeps the point where it is' do
      expect(root.keys).not_to include('data-car--map--component-movable-value')
    end
  end
end
