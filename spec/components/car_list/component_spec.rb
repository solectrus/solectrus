describe CarList::Component, type: :component do
  let(:car) { Car.configured.first }

  before { car.update!(name: 'Model Y', short_name: 'MY', active_from: Date.new(2024, 3, 1)) }

  it 'renders a row per car' do
    render_inline(described_class.new(cars: [car]))

    aggregate_failures do
      expect(page).to have_text('Model Y')
      expect(page).to have_text('MY')
      expect(page).to have_text("#{I18n.l(Date.new(2024, 3, 1))} – #{I18n.t('settings.cars.today')}")
    end
  end

  it 'shows a hint without cars' do
    render_inline(described_class.new(cars: []))

    expect(page).to have_css('code', text: 'INFLUX_SENSOR_CAR_ODOMETER_1')
  end
end
