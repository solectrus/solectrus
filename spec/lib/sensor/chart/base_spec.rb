describe Sensor::Chart::Base do
  # Use a concrete dense chart (house_power, default 15-min max_age) to prove
  # the sparse/persistent treatment is driven by the sensor's max_age, not by
  # any specific chart subclass.
  subject(:chart) { Sensor::Chart::HousePower.new(timeframe: Timeframe.now) }

  describe '#build_dataset' do
    it 'omits the tooltip unit while the chart does not pin one' do
      dataset = chart.__send__(:build_dataset, :house_power, { data: [1, 2] })

      expect(dataset).not_to have_key(:tooltipUnit)
    end
  end

  describe '#sparse?' do
    it 'is false for a sensor with the default max_age' do
      expect(chart.__send__(:sparse?)).to be(false)
    end

    it 'becomes true once the sensor raises its max_age above the default' do
      allow(Sensor::Registry[:house_power]).to receive(:max_age).and_return(
        2.hours,
      )

      expect(chart.__send__(:sparse?)).to be(true)
    end
  end

  context 'with a dense sensor (default max_age)' do
    it 'does not seed a leading-edge lookback' do
      expect(chart.__send__(:series_lookback)).to eq(0)
    end

    it 'keeps the default gap bridge limit instead of max_age' do
      expect(chart.__send__(:gap_bridge_limit)).to eq(5.minutes.in_milliseconds)
    end

    it 'does not render stepped lines' do
      style = chart.__send__(:style_for_sensor, Sensor::Registry[:house_power])
      expect(style).not_to have_key(:stepped)
    end

    it 'interpolates a gap linearly rather than holding a flat step' do
      labels = Array.new(4) { |i| Time.zone.local(2025, 3, 3, 10, i).to_i * 1000 }
      result = chart.__send__(:bridge_short_gaps, labels, [10.0, nil, nil, 40.0])

      # Linear ramp between the two samples, not a flat hold at 10.
      expect(result).to eq([10.0, 20.0, 30.0, 40.0])
    end
  end
end
