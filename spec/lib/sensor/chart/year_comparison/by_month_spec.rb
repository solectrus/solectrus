describe Sensor::Chart::YearComparison::ByMonth do
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
        date: Date.new(2023, 5, 20),
        values: [[:house_power, :sum, 500.0]],
      )
      create_summary(
        date: Date.new(2024, 5, 10),
        values: [[:house_power, :sum, 2000.0]],
      )
      create_summary(
        date: Date.new(2024, 7, 10),
        values: [[:house_power, :sum, 800.0]],
      )
    end

    it 'labels the x axis with the twelve months' do
      expect(chart.data[:labels].size).to eq(12)
    end

    it 'builds one dataset per year that measured something' do
      expect(chart.data[:datasets].pluck(:label)).to eq(%w[2023 2024])
    end

    it 'sums the days of a month' do
      values = chart.data[:datasets].first[:data]

      expect(values.pluck(:y)).to eq([1500.0])
    end

    it 'places a value in the month it belongs to' do
      expect(chart.data[:datasets].first[:data].first[:x]).to eq(
        I18n.t('date.abbr_month_names')[5],
      )
    end

    it 'leaves out the months without data' do
      values = chart.data[:datasets].second[:data]

      expect(values.pluck(:x)).to eq(
        I18n.t('date.abbr_month_names').values_at(5, 7),
      )
    end

    it 'points a click at the month it was aimed at' do
      expect(chart.data[:datasets].first[:data].first[:drilldownPath]).to eq(
        '/house_power/2023-05',
      )
    end

    it 'draws the newest year in the full color and the older ones paler' do
      opacities = chart.data[:datasets].pluck(:opacity)

      expect(opacities).to eq([0.45, 1.0])
    end

    it 'gives every year a stack of its own' do
      expect(chart.data[:datasets].pluck(:stack)).to eq(%w[2023 2024])
    end

    it 'is not blank' do
      expect(chart).not_to be_blank
    end

    it 'averages a month across the years' do
      expect(chart.data[:averages][:house_power][4]).to eq(1750.0)
    end

    # One year alone is its own average.
    it 'leaves a month of a single year without an average' do
      expect(chart.data[:averages][:house_power][6]).to be_nil
    end

    it 'names the average for the tooltip' do
      expect(chart.data[:averageLabel]).to eq(I18n.t('data.average'))
    end

    it 'leaves a month that is over unmarked' do
      point = chart.data[:datasets].first[:data].first

      expect(point).not_to have_key(:partial)
    end

    # The record begins on the day the installation went live, so its first
    # month counts from that day rather than from the first of the month.
    context 'with the first month of the record' do
      let(:timeframe) { Timeframe.new('all', min_date: Date.new(2023, 5, 17)) }

      it 'marks the bar of the month the record begins in' do
        point = chart.data[:datasets].first[:data].first

        expect(point[:partial]).to be(true)
      end

      # The hatched May of 2023 leaves one complete May, too few to average.
      it 'keeps the month out of the average' do
        expect(chart.data[:averages][:house_power][4]).to be_nil
      end

      context 'when the record begins on the first of the month' do
        let(:timeframe) { Timeframe.new('all', min_date: Date.new(2023, 5, 1)) }

        it 'leaves the bar alone' do
          point = chart.data[:datasets].first[:data].first

          expect(point).not_to have_key(:partial)
        end
      end
    end

    # A month still running has fewer days behind it than the months it stands
    # next to, so its bar is drawn hatched.
    context 'with a value in the month that is still running' do
      before do
        create_summary(
          date: Date.current.beginning_of_month,
          values: [[:house_power, :sum, 3000.0]],
        )
      end

      it 'marks the bar of the running month' do
        dataset = chart.data[:datasets].find { _1[:label] == Date.current.year.to_s }
        point = dataset[:data].find { _1[:x] == I18n.t('date.abbr_month_names')[Date.current.month] }

        expect(point[:partial]).to be(true)
        expect(dataset[:hatchPartial]).to be(true)
      end
    end

    # The axis has room for "Sep" only, and it cannot name the year at all.
    # The tooltip speaks for one bar, so it names both.
    it 'names the month and the year in the tooltip' do
      expect(chart.data[:datasets].first[:data].first[:tooltipTitle]).to eq(
        "#{I18n.t('date.month_names')[5]} 2023",
      )
    end

    it 'leaves the year out of the tooltip rows' do
      expect(chart.data[:datasets].pluck(:tooltipPrefix)).to all(be(false))
    end
  end

  # The regular chart draws export upward and import downward. The comparison
  # keeps that pair, one place per year and month.
  describe '#data of the grid' do
    let(:sensor_name) { :grid_import_power }
    let(:datasets) { chart.data[:datasets] }

    before do
      create_summary(
        date: Date.new(2023, 5, 10),
        values: [[:grid_import_power, :sum, 300.0], [:grid_export_power, :sum, 900.0]],
      )
      create_summary(
        date: Date.new(2024, 5, 10),
        values: [[:grid_import_power, :sum, 100.0], [:grid_export_power, :sum, 700.0]],
      )
    end

    it 'builds one dataset per year and direction' do
      export, import = %i[grid_export_power grid_import_power].map { Sensor::Registry[it].display_name }

      expect(datasets.pluck(:label)).to eq([export, import, export, import])
    end

    it 'puts the pair of a year into one stack' do
      expect(datasets.pluck(:stack)).to eq(%w[2023 2023 2024 2024])
    end

    it 'draws export upward and import downward' do
      expect(datasets.map { it[:data].first[:y] }).to eq(
        [900.0, -300.0, 700.0, -100.0],
      )
    end

    it 'names the direction, as the tooltip names the year already' do
      expect(datasets.first[:label]).to eq(
        Sensor::Registry[:grid_export_power].display_name,
      )
      expect(datasets.pluck(:tooltipPrefix)).to all(be_nil)
    end

    it 'shows magnitudes in the tooltip' do
      expect(datasets.pluck(:tooltipAbs)).to all(be(true))
    end

    it 'averages each direction on its own' do
      expect(chart.data[:averages][:grid_export_power][4]).to eq(800.0)
      expect(chart.data[:averages][:grid_import_power][4]).to eq(-200.0)
    end

    it 'labels the y axis with magnitudes' do
      expect(chart.options.dig(:scales, :y, :ticks, :callback)).to eq(
        'formatAbs',
      )
    end
  end

  describe '#data without any summary' do
    it 'is blank' do
      expect(chart).to be_blank
    end
  end

  describe '#options' do
    it 'puts the months on a category axis' do
      expect(chart.options.dig(:scales, :x, :type)).to eq('category')
    end

    # The axis names the months without a year, so nothing else says which of
    # the twelve is the one we are in.
    it 'draws the label of the running month in bold' do
      expect(chart.options.dig(:scales, :x, :ticks, :emphasize)).to eq(
        Date.current.month - 1,
      )
    end

    it 'stacks the years apart, not their values' do
      expect(chart.options.dig(:scales, :x, :stacked)).to be(true)
      expect(chart.options.dig(:scales, :y, :stacked)).to be(false)
    end

    # Every bar is a month of a year and stands on its own. Reading the whole
    # month at once would also leave a click without a year to drill into.
    it 'reads the one bar under the cursor' do
      expect(chart.options.dig(:interaction, :intersect)).to be(true)
      expect(chart.options.dig(:interaction, :mode)).to eq('nearest')
    end

    # Bars of a month differ a lot in height, so a tooltip fixed to the middle
    # of the plot would often stand far from what it reads.
    it 'puts the tooltip at the height of the bars' do
      expect(chart.options.dig(:plugins, :tooltip, :anchorToValues)).to be(true)
    end
  end

  describe '#type' do
    it 'is a bar chart' do
      expect(chart.type).to eq('bar')
    end
  end

  describe '#permitted_feature_name' do
    context 'with a free sensor' do
      it 'is free as well' do
        expect(chart.permitted_feature_name).to be_nil
      end
    end

    # A chart that only rearranges the bars of a finance chart shows the same
    # numbers, so it must not open a gate the regular chart keeps shut.
    context 'with a finance sensor' do
      let(:sensor_name) { :grid_costs }

      it 'keeps the gate of the regular chart' do
        expect(chart.permitted_feature_name).to eq(:finance_charts)
      end
    end
  end

  # The regular chart of `all` sums every bucket, because it draws one bar per
  # year. A bucket here is a month, so a sensor measured in percent has to
  # average its days again instead of adding them up.
  describe 'aggregation of a month' do
    context 'with a sensor measured in percent' do
      subject(:chart) do
        described_class.new(timeframe:, sensor_name: :battery_soc)
      end

      before do
        create_summary(
          date: Date.new(2024, 5, 10),
          values: [[:battery_soc, :avg, 40.0]],
        )
        create_summary(
          date: Date.new(2024, 5, 20),
          values: [[:battery_soc, :avg, 60.0]],
        )
      end

      it 'averages the days of the month' do
        values = chart.data[:datasets].first[:data]

        expect(values.pluck(:y)).to eq([50.0])
      end
    end

    context 'with a sensor measured in watt' do
      before do
        create_summary(
          date: Date.new(2024, 5, 10),
          values: [[:house_power, :sum, 40.0]],
        )
        create_summary(
          date: Date.new(2024, 5, 20),
          values: [[:house_power, :sum, 60.0]],
        )
      end

      it 'sums the days of the month' do
        values = chart.data[:datasets].first[:data]

        expect(values.pluck(:y)).to eq([100.0])
      end
    end
  end
end
