describe Sensor::Chart::YearComparison::ByQuarter do
  subject(:chart) { described_class.new(timeframe:, sensor_name:) }

  let(:timeframe) { Timeframe.all }
  let(:sensor_name) { :house_power }

  describe '#data' do
    before do
      create_summary(
        date: Date.new(2023, 5, 10),
        values: [[:house_power, :sum, 1000.0]],
      )
      create_summary(
        date: Date.new(2023, 6, 20),
        values: [[:house_power, :sum, 500.0]],
      )
      create_summary(
        date: Date.new(2024, 5, 10),
        values: [[:house_power, :sum, 2000.0]],
      )
      create_summary(
        date: Date.new(2024, 8, 10),
        values: [[:house_power, :sum, 800.0]],
      )
    end

    it 'labels the x axis with the four quarters' do
      expect(chart.data[:labels]).to eq(%w[Q1 Q2 Q3 Q4])
    end

    it 'builds one dataset per year that measured something' do
      expect(chart.data[:datasets].pluck(:label)).to eq(%w[2023 2024])
    end

    # Both days fall into the second quarter, which draws them as one bar.
    it 'sums the months of a quarter' do
      values = chart.data[:datasets].first[:data]

      expect(values.pluck(:y)).to eq([1500.0])
    end

    it 'places a value in the quarter it belongs to' do
      expect(chart.data[:datasets].first[:data].first[:x]).to eq('Q2')
    end

    it 'leaves out the quarters without data' do
      values = chart.data[:datasets].second[:data]

      expect(values.pluck(:x)).to eq(%w[Q2 Q3])
    end

    # No timeframe names a quarter, so the click leads to the three months of
    # it as a range.
    it 'points a click at the quarter it was aimed at' do
      expect(chart.data[:datasets].first[:data].first[:drilldownPath]).to eq(
        '/house_power/2023-04-01..2023-06-30',
      )
    end

    it 'draws the newest year in the full color and the older ones paler' do
      expect(chart.data[:datasets].pluck(:opacity)).to eq([0.45, 1.0])
    end

    it 'gives every year a stack of its own' do
      expect(chart.data[:datasets].pluck(:stack)).to eq(%w[2023 2024])
    end

    it 'leaves a quarter that is over unmarked' do
      point = chart.data[:datasets].first[:data].first

      expect(point).not_to have_key(:partial)
    end

    # The record begins on the day the installation went live, so its first
    # quarter counts from that day rather than from the first of April.
    context 'with the first quarter of the record' do
      let(:timeframe) { Timeframe.new('all', min_date: Date.new(2023, 5, 17)) }

      it 'marks the bar of the quarter the record begins in' do
        point = chart.data[:datasets].first[:data].first

        expect(point[:partial]).to be(true)
      end

      context 'when the record begins on the first day of a quarter' do
        let(:timeframe) { Timeframe.new('all', min_date: Date.new(2023, 4, 1)) }

        it 'leaves the bar alone' do
          point = chart.data[:datasets].first[:data].first

          expect(point).not_to have_key(:partial)
        end
      end
    end

    # A quarter still running has fewer days behind it than the quarters it
    # stands next to, so its bar is drawn hatched.
    context 'with a value in the quarter that is still running' do
      before do
        create_summary(
          date: Date.current.beginning_of_quarter,
          values: [[:house_power, :sum, 3000.0]],
        )
      end

      it 'marks the bar of the running quarter' do
        dataset =
          chart.data[:datasets].find { it[:label] == Date.current.year.to_s }
        point = dataset[:data].find { it[:x] == "Q#{Date.current.quarter}" }

        expect(point[:partial]).to be(true)
        expect(dataset[:hatchPartial]).to be(true)
      end
    end

    # The axis says "Q2" only, and it names no year. The tooltip speaks for one
    # bar, so it names both.
    it 'names the quarter and the year in the tooltip' do
      expect(chart.data[:datasets].first[:data].first[:tooltipTitle]).to eq(
        I18n.t('data.quarter_with_year', quarter: 2, year: 2023),
      )
    end
  end

  describe '#data without any summary' do
    it 'is blank' do
      expect(chart).to be_blank
    end
  end

  describe '#options' do
    it 'puts the quarters on a category axis' do
      expect(chart.options.dig(:scales, :x, :type)).to eq('category')
    end

    it 'draws the label of the running quarter in bold' do
      expect(chart.options.dig(:scales, :x, :ticks, :emphasize)).to eq(
        Date.current.quarter - 1,
      )
    end

    it 'stacks the years apart, not their values' do
      expect(chart.options.dig(:scales, :x, :stacked)).to be(true)
      expect(chart.options.dig(:scales, :y, :stacked)).to be(false)
    end
  end

  # A bucket here is a quarter, so a sensor measured in percent has to average
  # its days again instead of adding them up.
  describe 'aggregation of a quarter' do
    context 'with a sensor measured in percent' do
      subject(:chart) do
        described_class.new(timeframe:, sensor_name: :battery_soc)
      end

      before do
        create_summary(
          date: Date.new(2024, 4, 10),
          values: [[:battery_soc, :avg, 40.0]],
        )
        create_summary(
          date: Date.new(2024, 6, 20),
          values: [[:battery_soc, :avg, 60.0]],
        )
      end

      it 'averages the days of the quarter' do
        values = chart.data[:datasets].first[:data]

        expect(values.pluck(:y)).to eq([50.0])
      end
    end
  end
end
