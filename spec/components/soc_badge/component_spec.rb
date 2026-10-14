describe SocBadge::Component, type: :component do
  subject(:html) do
    render_inline(described_class.new(battery_soc: 75.0, car: Car.new(id: 1), car_soc: 12.0, car_connected:, time: Time.current, timeframe: Timeframe.now))
  end

  let(:car_connected) { true }
  let(:car_icon_classes) { html.css('.soc-icon').last[:class].split }

  it 'shows both states of charge in the color of their level' do
    expect(html.css('.soc-value').map { it.text.strip }).to eq(%w[75% 12%])
    expect(html.css('.soc-value').last[:class]).to include('text-signal-warning')
  end

  it 'links the car to the car page, out of the frame' do
    expect(html.at_css("a[href='/cars/now']")['data-turbo-frame']).to eq('_top')
  end

  context 'with the car at the plug' do
    it 'shows the car icon in full color' do
      expect(car_icon_classes).to include('text-slate-500')
    end
  end

  context 'without the car at the plug' do
    let(:car_connected) { false }

    it 'fades the car icon' do
      expect(car_icon_classes).to include('text-slate-400')
    end
  end
end
