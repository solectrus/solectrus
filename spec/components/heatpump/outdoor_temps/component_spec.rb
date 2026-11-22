describe Heatpump::OutdoorTemps::Component, type: :component do
  subject(:page) { render_inline(described_class.new(average: 13.5, heating: 7.2)) }

  def tooltip(element) = element.css('[data-tooltip-target="html"] > *').map { it.text.squish }

  it 'explains each temperature in a tooltip of its own' do
    average, heating = page.css('[data-controller="tooltip"]')

    expect(tooltip(average)).to eq(['Outdoor temperature', 'Average of all days'])
    expect(tooltip(heating).first).to eq('Outdoor temperature while heating')
    expect(heating.at_css('.sr-only').text).to eq('Outdoor temperature while heating')
  end
end
