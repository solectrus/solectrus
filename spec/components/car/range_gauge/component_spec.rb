describe Car::RangeGauge::Component, type: :component do
  subject(:component) { described_class.new(state:) }

  let(:state) { Car::Live::State.new(car: Car.new(id: 2), soc:, range:, max_range:, odometer: nil, connected: nil, charging_power: nil, latitude: nil, longitude: nil) }
  let(:soc) { 62.0 }
  let(:range) { 208 }
  let(:max_range) { 335 }
  let(:html) { render_inline(component) }

  def stale = 'No current values'
  def env = { 'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc', 'INFLUX_SENSOR_CAR_RANGE_2' => 'Wartburg:range' }

  before do
    stub_const('ENV', ENV.to_h.merge(env))
    stub_feature(:car)
  end

  it 'fills the arc to the state of charge' do
    expect(html.css('path[stroke-dasharray="62 100"]')).to be_present
  end

  it 'shows the range, the state of charge and the maximum range' do
    expect(html.text.squish).to include('208', '62 %', '335')
  end

  # The live view has no chart, so no value links to one
  it 'links nowhere' do
    expect(html.css('a')).to be_empty
  end

  describe 'the color of the level' do
    [[62.0, 'bg-car-battery'], [20.0, 'bg-signal-warning'], [5.0, 'bg-signal-negative']].each do |value, css_class|
      context "with #{value.to_i} %" do
        let(:soc) { value }

        it 'colors the badge by the level and keeps the arc blue' do
          expect(html.css("div.#{css_class}")).to be_present
          expect(html.css('path.stroke-car-battery')).to be_present
        end
      end
    end
  end

  # The sensor of the state of charge never sent a value
  context 'without a current state of charge' do
    let(:soc) { nil }

    it 'shows the empty arc, the range and that the values are not current' do
      expect(html.css('svg')).to be_present
      expect(html.css('path[stroke-dasharray]')).to be_empty
      expect(html.text).to include('208', stale)
    end
  end

  context 'without a current range' do
    let(:range) { nil }

    it 'shows the range as missing and that the values are not current' do
      expect(html.text).to include('–', stale)
    end
  end

  context 'without a sensor of the state of charge' do
    def env = { 'INFLUX_SENSOR_CAR_RANGE_2' => 'Wartburg:range' }
    let(:soc) { nil }

    it 'shows the range in a gray arc, without a scale and without a note' do
      expect(html.css('svg path').size).to eq(1)
      expect(html.text).to include('208')
      expect(html.css('div[class*="top-[93%]"]')).to be_empty
      expect(html.text).not_to include(stale)
    end
  end

  context 'without a sensor of the range' do
    def env = { 'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc' }
    let(:range) { nil }
    let(:max_range) { nil }

    it 'shows the arc without a range and without a scale' do
      expect(html.css('path[stroke-dasharray="62 100"]')).to be_present
      expect(html.text).not_to include('km', stale)
    end
  end

  it 'shows that the values are current' do
    expect(html.text).not_to include(stale)
  end

  it 'shows no plug and no charging power without a reading' do
    expect(html.css('[role="img"]')).to be_empty
    expect(html.text).not_to include(' W')
  end

  context 'with the plug of the car' do
    let(:state) { Car::Live::State.new(car: Car.new(id: 2), soc:, range:, max_range:, odometer: nil, connected: true, charging_power: 7_400, latitude: nil, longitude: nil) }

    # The icon alone, so the tooltip gives the text
    it 'shows the plug and the charging power below the state of charge' do
      plug = html.at_css('[role="img"]')

      expect(plug['title']).to eq(I18n.t('sensors.wallbox_car_connected_short'))
      expect(html.to_html.index('62 %')).to be < html.to_html.index('role="img"')
      expect(html.text).to include('7.4')
    end
  end

  context 'with the car unplugged' do
    let(:state) { Car::Live::State.new(car: Car.new(id: 2), soc:, range:, max_range:, odometer: nil, connected: false, charging_power: 0, latitude: nil, longitude: nil) }

    it 'shows the plug without the charging power' do
      expect(html.css('[role="img"]')).to be_present
      expect(html.text).not_to include(' W')
    end
  end

  it 'puts its block above the arc' do
    html = render_inline(component) { 'Pills' }

    expect(html.to_html.index('Pills')).to be < html.to_html.index('<svg')
  end
end
