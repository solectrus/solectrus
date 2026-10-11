describe Car::Select::Component, type: :component do
  subject(:component) { described_class.new(cars:, car: cars.first, path: ->(id) { "/cars/#{id}" }) }

  let(:cars) { [Car.create!(id: 1, name: 'Renault Voltaire', short_name: 'Volt'), Car.create!(id: 2, name: 'Model Y', short_name: 'MY')] }
  let(:html) { render_inline(component) }

  it 'shows the short name on the button and the full name in the menu' do
    expect(html.at_css('button#options-menu').text.squish).to eq('Volt')
    expect(html.css('[role=menu] a').map { it.text.squish }).to include('Renault Voltaire', 'Model Y')
  end

  context 'with the guests' do
    subject(:component) { described_class.new(cars:, car: nil, guest: true, guest_selected: true, path: ->(id) { "/cars/#{id}" }) }

    it 'offers them last and selects them' do
      expect(html.css('[role=menu] a').map { it.text.squish }).to eq(['All cars', 'Renault Voltaire', 'Model Y', 'Guest'])
      expect(html.css('[role=menu] a').pluck('href').last).to eq('/cars/guest')
      expect(html.at_css('button#options-menu').text.squish).to eq('Guest')
    end
  end

  # "all" adds the guest sessions to the one car
  context 'with one car' do
    subject(:component) { described_class.new(cars: cars.first(1), car: nil, path: ->(id) { "/cars/#{id}" }) }

    it 'offers "all" and the car, and selects "all"' do
      expect(html.css('[role=menu] a').map { it.text.squish }).to eq(['All cars', 'Renault Voltaire'])
      expect(html.at_css('button#options-menu').text.squish).to eq('All cars')
    end
  end
end
