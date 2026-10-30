describe Place::List::Row::Component, type: :component do
  let(:place) { Place.with_seconds.find(Place.create!(latitude: 50.92263, longitude: 1.40706, name: 'Work', geocoding: { 'address' => { 'town' => 'Springfield' } }).id) }

  it 'opens the place from a row, in a sheet on a phone' do
    render_inline(described_class.new(place:))

    aggregate_failures do
      expect(page).to have_css("#place_#{place.id}")
      expect(page).to have_css("[data-ui--table-row--component-form-sheet-value] a[href='/settings/places/#{place.id}/edit']", text: 'Work', count: 1)
      expect(page).to have_text('Springfield')
      expect(page).to have_no_text('50.92263')
    end
  end

  it 'names an unnamed place as such, with its locality below' do
    render_inline(described_class.new(place: Place.with_seconds.find(Place.create!(latitude: 51.0, longitude: 7.0, geocoding: { 'address' => { 'town' => 'Riverton' } }).id)))

    expect(page).to have_css('.italic', text: I18n.t('settings.places.unnamed'))
    expect(page).to have_text('Riverton')
  end

  it 'leaves out the time without visits' do
    render_inline(described_class.new(place:))

    expect(page).to have_no_link(href: %r{/cars/visits})
  end
end
