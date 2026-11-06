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

  describe '#initialize' do
    it 'rejects a timeframe that is no Timeframe' do
      expect { Sensor::Chart::HousePower.new(timeframe: 'P7D') }.to raise_error(
        ArgumentError,
        'timeframe must be a Timeframe, got "P7D"',
      )
    end
  end

  describe 'x axis of a relative timeframe of days' do
    def day_format(string)
      Sensor::Chart::HousePower.new(timeframe: Timeframe.new(string))
        .options.dig(:scales, :x, :time, :displayFormats, :day)
    end

    it 'names the weekday for a week' do
      expect(day_format('P7D')).to eq('ccc')
    end

    it 'names the day for a month' do
      expect(day_format('P30D')).to eq('d')
    end

    it 'names day and month for some months' do
      expect(day_format('P90D')).to eq('d. LLL')
    end

    it 'names month and year for about a year' do
      expect(day_format('P365D')).to eq('LLL yyyy')
    end
  end

  describe 'SQL series with a meta aggregation of min or max' do
    subject(:values) { chart.data[:datasets].first[:data] }

    let(:chart) { chart_class.new(timeframe: Timeframe.new('2024')) }

    def chart_class_for(aggregation)
      Class.new(described_class) do
        define_method(:chart_sensor_names) { %i[outdoor_temp] }

        private

        define_method(:sql_aggregations_for_sensor) { |_name| [aggregation, aggregation] }
      end
    end

    before do
      create_summary(date: '2024-01-10', values: [[:outdoor_temp, :min, -4.0], [:outdoor_temp, :max, 6.0]])
      create_summary(date: '2024-01-11', values: [[:outdoor_temp, :min, -7.0], [:outdoor_temp, :max, 3.0]])
    end

    context 'with min' do
      let(:chart_class) { chart_class_for(:min) }

      it 'draws the lowest value of each month' do
        expect(values.first).to eq(-7.0)
      end
    end

    context 'with max' do
      let(:chart_class) { chart_class_for(:max) }

      it 'draws the highest value of each month' do
        expect(values.first).to eq(6.0)
      end
    end
  end
end
