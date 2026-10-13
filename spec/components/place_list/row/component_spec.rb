describe PlaceList::Row::Component, type: :component do
  let(:place) { Place.with_seconds.find(Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Work', geocoding: { 'address' => { 'town' => 'Jülich' } }).id) }

  it 'shows the place with a button that opens its form in the modal' do
    render_inline(described_class.new(place:))

    aggregate_failures do
      expect(page).to have_css("#place_#{place.id}", text: 'Work')
      expect(page).to have_css("form[action='/settings/places/#{place.id}/edit'] button[data-turbo-frame='modal']")
      expect(page).to have_text('Jülich · 50.92263, 6.40706')
    end
  end

  it 'names an unnamed place as such' do
    render_inline(described_class.new(place: Place.with_seconds.find(Place.create!(latitude: 51.0, longitude: 7.0).id)))

    expect(page).to have_css('.italic', text: I18n.t('settings.places.unnamed'))
  end

  it 'leaves out the time without visits' do
    render_inline(described_class.new(place:))

    expect(page).to have_no_link(href: %r{/cars/visits})
  end
end
