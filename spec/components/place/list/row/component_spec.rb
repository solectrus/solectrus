describe Place::List::Row::Component, type: :component do
  let(:place) { Place.with_seconds.find(Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Work', geocoding: { 'address' => { 'town' => 'Jülich' } }).id) }

  it 'opens the place from a row for both layouts' do
    render_inline(described_class.new(place:))

    aggregate_failures do
      expect(page).to have_css("#place_#{place.id}")
      expect(page).to have_css("a[href='/settings/places/#{place.id}/edit'][data-nav-title]", text: 'Work', count: 1)
      expect(page).to have_text('Jülich')
      expect(page).to have_no_text('50.92263')
    end
  end

  it 'names an unnamed place as such, with its locality below' do
    render_inline(described_class.new(place: Place.with_seconds.find(Place.create!(latitude: 51.0, longitude: 7.0, geocoding: { 'address' => { 'town' => 'Düren' } }).id)))

    expect(page).to have_css('.italic', text: I18n.t('settings.places.unnamed'))
    expect(page).to have_text('Düren')
  end

  it 'leaves out the time without visits' do
    render_inline(described_class.new(place:))

    expect(page).to have_no_link(href: %r{/cars/visits})
  end
end
