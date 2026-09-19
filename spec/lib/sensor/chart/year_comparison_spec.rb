describe Sensor::Chart::YearComparison do
  describe '.available_for?' do
    it 'accepts a sensor with a value of its own' do
      expect(described_class).to be_available_for(Sensor::Registry[:house_power])
    end

    it 'rejects a chart-only sensor' do
      expect(described_class).not_to be_available_for(
        Sensor::Registry[:power_balance],
      )
    end

    it 'rejects a missing sensor' do
      expect(described_class).not_to be_available_for(nil)
    end
  end

  describe '.for' do
    it 'finds the comparison by month' do
      expect(described_class.for('by_month')).to eq(described_class::ByMonth)
    end

    it 'answers nothing for an unknown spelling' do
      expect(described_class.for('by_week')).to be_nil
    end

    it 'answers nothing for no spelling at all' do
      expect(described_class.for(nil)).to be_nil
    end
  end

  # The route reads the segment off the path with this, so it must match every
  # spelling a comparison carries and nothing else.
  describe '.regex' do
    it 'matches every comparison' do
      expect(described_class.variants.map { it::PARAM }).to all(
        match(described_class.regex),
      )
    end

    it 'matches nothing else' do
      expect(described_class.regex).not_to match('by_week')
    end
  end

  # A comparison takes the color from the regular chart of its sensor, which
  # means calling #color_class on another object. A chart that hides the
  # method behind `private` breaks the comparison of its sensor.
  describe 'the color of a chart' do
    before do
      Rails.autoloaders.main.eager_load_dir(
        Rails.root.join('app', 'lib', 'sensor', 'chart'),
      )
    end

    it 'is public in every chart class' do
      hidden =
        Sensor::Chart::Base.descendants.reject do
          it.public_method_defined?(:color_class)
        end

      expect(hidden).to be_empty
    end
  end
end
