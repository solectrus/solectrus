describe Sensor::Chart::Base do
  # Use a concrete chart (house_power) to prove that the treatment of a state
  # is driven by the sensor (see the DSL `state`), not by any specific chart
  # subclass.
  subject(:chart) { Sensor::Chart::HousePower.new(timeframe: Timeframe.now) }

  describe '#holds_value?' do
    it 'is false for a sensor that is no state' do
      expect(chart.__send__(:holds_value?)).to be(false)
    end

    it 'is true for a state' do
      allow(Sensor::Registry[:house_power]).to receive(:state?).and_return(true)

      expect(chart.__send__(:holds_value?)).to be(true)
    end
  end

  context 'with a sensor that is no state' do
    it 'keeps the default gap bridge limit' do
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
