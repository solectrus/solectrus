describe DonutChart::Component, type: :component do
  let(:segments) do
    [
      {
        percent: 60,
        color_var: '--color-sensor-heatpump-env',
        label: 'Umwelt',
        sensor_name: 'heatpump_power_env',
      },
      {
        percent: 40,
        color_var: '--color-sensor-heatpump',
        label: 'Gesamt',
        sensor_name: 'heatpump_power',
      },
    ]
  end

  let(:url) { '/heatpump' }
  let(:chart_url) { '/heatpump/charts' }

  describe '#donut_style' do
    subject(:donut_style) do
      described_class.new(segments:, url:, chart_url:).donut_style
    end

    it 'includes all segment colors' do
      expect(donut_style).to include('--color-sensor-heatpump-env')
      expect(donut_style).to include('--color-sensor-heatpump')
    end

    context 'with multiple segments' do
      it 'includes gaps between segments' do
        gap_count = donut_style.scan('transparent').size
        # Mask uses 'transparent' twice, gaps add more
        expect(gap_count).to be > 2
      end
    end
  end

  describe '#placeholder?' do
    it 'is true without segments' do
      expect(described_class.new).to be_placeholder
    end

    it 'is false with segments' do
      component = described_class.new(segments:, url:, chart_url:)
      expect(component).not_to be_placeholder
    end
  end
end
