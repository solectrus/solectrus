describe Car::RangeGauge::Component, type: :component do
  subject(:component) { described_class.new(live:, timeframe: Timeframe.now) }

  let(:live) { Car::Balance::Live.new(car: Car.new(id: 2), soc:, range:, max_range:, odometer: nil) }
  let(:soc) { 62.0 }
  let(:range) { 208 }
  let(:max_range) { 335 }
  let(:html) { render_inline(component) }

  it 'fills the arc to the state of charge' do
    expect(html.css('path[stroke-dasharray="62 100"]')).to be_present
  end

  it 'shows the range, the state of charge and the maximum range' do
    expect(html.text.squish).to include('208', '62 %', '335')
  end

  it 'loads the chart of each value' do
    urls = html.css('a').filter_map { it['data-stats-with-chart--component-chart-url-param'] }

    expect(urls.uniq).to contain_exactly(
      a_string_including('car_battery_soc_2'),
      a_string_including('car_range_2'),
      a_string_including('car_max_range_2'),
    )
  end

  describe 'the color of the level' do
    [[62.0, 'stroke-sensor-battery'], [20.0, 'stroke-signal-warning'], [5.0, 'stroke-signal-negative']].each do |value, css_class|
      context "with #{value.to_i} %" do
        let(:soc) { value }

        it { expect(html.css("path.#{css_class}")).to be_present }
      end
    end
  end

  context 'without a state of charge' do
    let(:soc) { nil }

    it 'shows the empty arc and the range' do
      expect(html.css('path[stroke-dasharray]')).to be_empty
      expect(html.text).to include('208')
    end
  end

  it 'puts its block above the arc' do
    html = render_inline(component) { 'Pills' }

    expect(html.to_html.index('Pills')).to be < html.to_html.index('<svg')
  end
end
