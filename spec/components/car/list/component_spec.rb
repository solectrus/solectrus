describe Car::List::Component, type: :component do
  let(:car) { Car.configured.first }

  before { car.update!(name: 'Model Y', short_name: 'MY', active_from: Date.new(2024, 3, 1)) }

  it 'renders a row per car that opens the form of the car' do
    render_inline(described_class.new(cars: [car]))

    link = page.find("a[href='/settings/cars/#{car.id}/edit']")
    aggregate_failures do
      expect(link).to have_text('Model Y')
      expect(link['data-nav-title']).to eq(I18n.t('settings.cars.edit', number: car.id))
      expect(page).to have_text('MY')
      expect(page).to have_text("#{I18n.l(Date.new(2024, 3, 1))} – #{I18n.t('settings.cars.today')}")
    end
  end

  it 'shows a hint without cars' do
    render_inline(described_class.new(cars: []))

    expect(page).to have_css('code', text: 'INFLUX_SENSOR_CAR_ODOMETER_1')
  end
end
