describe SponsoringBenefits::Component, type: :component do
  subject(:component) { described_class.new }

  it 'names every feature' do
    result = render_inline(component)

    expect(result.to_html).to include('Custom consumers')
    expect(result.to_html).to include('Dark mode')
    expect(result.css('li').size).to eq(component.benefits.size)
  end

  # The component renders whatever the locale file lists, so a feature added to
  # one language alone would be missing in the other without a word of warning.
  it 'lists the same features in both languages' do
    keys =
      %w[de en].map do |locale|
        path =
          Rails.root.join(
            "app/components/sponsoring_benefits/component.#{locale}.yml",
          )

        YAML.load_file(path).dig(locale, 'benefits').keys
      end

    expect(keys.first).to eq(keys.last)
  end
end
