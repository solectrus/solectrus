describe Sensor::Chart::YearComparison::BySeason do
  subject(:chart) { described_class.new(timeframe:, sensor_name:) }

  let(:timeframe) { Timeframe.all }
  let(:sensor_name) { :house_power }

  def label(season)
    I18n.t("data.seasons.#{season}")
  end

  def dataset_of(year)
    chart.data[:datasets].find { it[:label] == year.to_s }
  end

  def point_of(year, season)
    dataset_of(year)[:data].find { it[:x] == label(season) }
  end

  describe '#data' do
    before do
      # The summer of 2023.
      create_summary(
        date: Date.new(2023, 7, 10),
        values: [[:house_power, :sum, 2000.0]],
      )
      # The winter of 2023, which runs on into February 2024.
      create_summary(
        date: Date.new(2023, 12, 10),
        values: [[:house_power, :sum, 1000.0]],
      )
      create_summary(
        date: Date.new(2024, 1, 20),
        values: [[:house_power, :sum, 500.0]],
      )
      # The summer of 2024.
      create_summary(
        date: Date.new(2024, 7, 10),
        values: [[:house_power, :sum, 3000.0]],
      )
    end

    it 'labels the x axis with the four seasons, spring first' do
      expect(chart.data[:labels]).to eq(
        [label(:spring), label(:summer), label(:autumn), label(:winter)],
      )
    end

    it 'builds one dataset per year that measured something' do
      expect(chart.data[:datasets].pluck(:label)).to eq(%w[2023 2024])
    end

    # A winter counts into the year it begins in, so the January that follows
    # it stands in one bar with the December before it.
    it 'counts a January into the winter of the year before' do
      expect(point_of(2023, :winter)[:y]).to eq(1500.0)
    end

    it 'keeps the seasons of a year in the order they ran in' do
      expect(dataset_of(2023)[:data].pluck(:x)).to eq(
        [label(:summer), label(:winter)],
      )
    end

    # No timeframe names a season, so the click leads to the three months of
    # it as a range. A winter reaches into the year that follows it.
    it 'points a click at the winter it was aimed at' do
      expect(point_of(2023, :winter)[:drilldownPath]).to eq(
        '/house_power/2023-12-01..2024-02-29',
      )
    end

    it 'points a click at the summer it was aimed at' do
      expect(point_of(2023, :summer)[:drilldownPath]).to eq(
        '/house_power/2023-06-01..2023-08-31',
      )
    end

    it 'names both years of a winter in the tooltip' do
      expect(point_of(2023, :winter)[:tooltipTitle]).to eq(
        "#{label(:winter)} 2023/24",
      )
    end

    it 'names the one year of a summer in the tooltip' do
      expect(point_of(2023, :summer)[:tooltipTitle]).to eq(
        "#{label(:summer)} 2023",
      )
    end

    it 'draws the newest year in the full color and the older ones paler' do
      expect(chart.data[:datasets].pluck(:opacity)).to eq([0.45, 1.0])
    end

    it 'leaves a season that is over unmarked' do
      expect(point_of(2023, :winter)).not_to have_key(:partial)
    end

    # The record begins on the day the installation went live, so the winter
    # it begins in counts from that day rather than from the first of
    # December.
    context 'with the first season of the record' do
      let(:timeframe) { Timeframe.new('all', min_date: Date.new(2023, 12, 6)) }

      it 'marks the bar of the season the record begins in' do
        expect(point_of(2023, :winter)[:partial]).to be(true)
      end

      context 'when the record begins on the first day of a season' do
        let(:timeframe) do
          Timeframe.new('all', min_date: Date.new(2023, 12, 1))
        end

        it 'leaves the bar alone' do
          expect(point_of(2023, :winter)).not_to have_key(:partial)
        end
      end
    end

    # A season still running has fewer days behind it than the seasons it
    # stands next to, so its bar is drawn hatched.
    context 'with a value in the season that is still running' do
      # The quarter a month ahead of today holds the season we are in, and
      # that season begins a month before it.
      let(:shifted) { (Date.current + 1.month).beginning_of_quarter }
      let(:beginning) { shifted - 1.month }

      before do
        create_summary(
          date: Date.current,
          values: [[:house_power, :sum, 4000.0]],
        )
      end

      it 'marks the bar of the running season' do
        dataset = dataset_of(beginning.year)
        point =
          dataset[:data].find do
            it[:x] == chart.data[:labels][(shifted.quarter + 2) % 4]
          end

        expect(beginning).to be <= Date.current
        expect(point[:partial]).to be(true)
        expect(dataset[:hatchPartial]).to be(true)
      end
    end
  end

  describe '#data without any summary' do
    it 'is blank' do
      expect(chart).to be_blank
    end
  end

  describe '#options' do
    it 'puts the seasons on a category axis' do
      expect(chart.options.dig(:scales, :x, :type)).to eq('category')
    end

    # September is autumn, although it is the third quarter of the calendar.
    it 'draws the label of the running season in bold' do
      expect(chart.options.dig(:scales, :x, :ticks, :emphasize)).to eq(
        ((Date.current + 1.month).quarter + 2) % 4,
      )
    end
  end

  # A bucket here is a season, so a sensor measured in percent has to average
  # its days again instead of adding them up.
  describe 'aggregation of a season' do
    context 'with a sensor measured in percent' do
      subject(:chart) do
        described_class.new(timeframe:, sensor_name: :battery_soc)
      end

      before do
        create_summary(
          date: Date.new(2023, 12, 10),
          values: [[:battery_soc, :avg, 40.0]],
        )
        create_summary(
          date: Date.new(2024, 2, 20),
          values: [[:battery_soc, :avg, 60.0]],
        )
      end

      it 'averages the days of the season' do
        expect(point_of(2023, :winter)[:y]).to eq(50.0)
      end
    end
  end
end
