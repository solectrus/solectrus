describe Car::Select::Component, type: :component do
  subject(:component) { described_class.new(cars:, car: cars.first, path: ->(id) { "/cars/#{id}" }) }

  let(:cars) { [Car.create!(id: 1, name: 'Renault Voltaire', short_name: 'Volt'), Car.create!(id: 2, name: 'Model Y', short_name: 'MY')] }
  let(:html) { render_inline(component) }

  it 'shows the short name on the button and the full name in the menu' do
    expect(html.at_css('button#options-menu').text.squish).to eq('Volt')
    expect(html.css('[role=menu] a').map { it.text.squish }).to include('Renault Voltaire', 'Model Y')
  end
end
