describe PlaceLabels::Component, type: :component do
  it 'names each label of the place' do
    render_inline(described_class.new(place: Place.new(labels: %w[home])))

    expect(page).to have_css("span[title='#{Place.human_label('home')}'] svg")
  end

  it 'renders nothing without a label' do
    render_inline(described_class.new(place: Place.new))

    expect(page.text).to be_empty
  end
end
