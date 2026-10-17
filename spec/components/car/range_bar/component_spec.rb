describe Car::RangeBar::Component, type: :component do
  subject(:component) { described_class.new(state:) }

  let(:state) { state_with(connected: nil, charging_power: nil) }
  let(:soc) { 62.0 }
  let(:range) { 208 }
  let(:max_range) { 335 }
  let(:html) { render_inline(component) }

  def state_with(connected:, charging_power:)
    Car::Live::State.new(car: Car.new(id: 2), soc:, range:, max_range:, odometer: nil, connected:, charging_power:, latitude: nil, longitude: nil)
  end

  def stale = 'No current values'
  def env = { 'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc', 'INFLUX_SENSOR_CAR_RANGE_2' => 'Wartburg:range' }

  before do
    stub_const('ENV', ENV.to_h.merge(env))
    stub_feature(:car)
  end

  it 'fills the bar to the state of charge, without an arc' do
    expect(html.css('div.bg-car-battery[style="width: 62%"]')).to be_present
    expect(html.css('svg')).to be_empty
  end

  it 'shows the range, the state of charge and the maximum range' do
    expect(html.text.squish).to include('208', I18n.t('sensors.car_range_short'), '62 %', '335')
    expect(html.text).not_to include(stale)
  end

  context 'without a current state of charge' do
    let(:soc) { nil }

    it 'shows the empty bar, the range and that the values are not current' do
      expect(html.css('div[style^="width"]')).to be_empty
      expect(html.text).to include('208', stale)
    end
  end

  context 'without a sensor of the range' do
    def env = { 'INFLUX_SENSOR_CAR_BATTERY_SOC_2' => 'Wartburg:soc' }
    let(:range) { nil }
    let(:max_range) { nil }

    it 'shows the state of charge in place of the range, without a scale' do
      expect(html.css('div.bg-car-battery.text-2xl').text).to eq('62 %')
      expect(html.text).not_to include('–', I18n.t('sensors.car_range_short'), 'km', stale)
    end

    # See Car::RangeEstimate
    context 'with an estimate' do
      let(:range) { 186.0 }
      let(:max_range) { 300.0 }

      it 'shows the range as an estimate with its source, and the scale' do
        expect(html.text.squish).to include('186', 'Estimated range', '62 %', '300')
        expect(html.at_css('[title^="Estimated from"]')).to be_present
      end
    end
  end

  context 'with the plug of the car' do
    let(:state) { state_with(connected: true, charging_power: 7_400) }

    it 'shows the plug and the charging power below the bar' do
      expect(html.at_css('[role="img"]')['title']).to eq(I18n.t('sensors.wallbox_car_connected_short'))
      expect(html.text).to include('7.4')
    end

    it 'pulses after the fill while the car charges' do
      expect(html.css('div.charging-pulse[style="left: 62%; width: 8%"]')).to be_present
    end
  end

  context 'with the car unplugged' do
    let(:state) { state_with(connected: false, charging_power: 0) }

    it 'shows the plug without the charging power, and no pulse' do
      expect(html.css('[role="img"]')).to be_present
      expect(html.text).not_to include(' W')
      expect(html.css('.charging-pulse')).to be_empty
    end
  end

  it 'puts its block above the bar' do
    html = render_inline(component) { 'Name' }

    expect(html.to_html.index('Name')).to be < html.to_html.index('width: 62%')
  end
end
