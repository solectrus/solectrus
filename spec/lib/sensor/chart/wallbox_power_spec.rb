describe Sensor::Chart::WallboxPower do
  subject(:chart) { described_class.new(timeframe:) }

  let(:timeframe) { Timeframe.new('2025-W10') }

  before { stub_feature(:power_splitter) }

  context 'with power splitter data' do
    before do
      # Monday
      create_summary(
        date: '2025-03-03',
        values: [
          [:wallbox_power, :sum, 17_000],
          [:wallbox_power_grid, :sum, 1_000],
        ],
      )

      # Tuesday
      # No data

      # Wednesday
      # No data

      # Thursday
      # No data

      # Friday
      create_summary(
        date: '2025-03-07',
        values: [
          [:wallbox_power, :sum, 15_000],
          [:wallbox_power_grid, :sum, 4_000],
        ],
      )

      # Saturday
      create_summary(
        date: '2025-03-08',
        values: [
          [:wallbox_power, :sum, 17_000],
          [:wallbox_power_grid, :sum, 1_000],
        ],
      )

      # Sunday
      create_summary(
        date: '2025-03-09',
        values: [
          [:wallbox_power, :sum, 15_000],
          [:wallbox_power_grid, :sum, 13_000],
        ],
      )
    end

    it 'builds label for every day' do
      expect(chart.data[:labels].length).to eq(7)
    end

    it 'builds three datasets with correct sparse data alignment' do
      chart.data[:datasets].tap do |datasets|
        expect(datasets.length).to eq(3)

        datasets.first.tap do |wallbox_power|
          expect(wallbox_power[:id]).to eq(:wallbox_power)
          expect(wallbox_power[:data]).to eq(
            [17_000, nil, nil, nil, 15_000, 17_000, 15_000],
          )
        end

        datasets.second.tap do |wallbox_power_grid|
          expect(wallbox_power_grid[:id]).to eq(:wallbox_power_grid)
          expect(wallbox_power_grid[:data]).to eq(
            [1_000, nil, nil, nil, 4_000, 1_000, 13_000],
          )
        end

        datasets.third.tap do |wallbox_power_pv|
          expect(wallbox_power_pv[:id]).to eq(:wallbox_power_pv)
          expect(wallbox_power_pv[:data]).to eq(
            [16_000, nil, nil, nil, 11_000, 16_000, 2_000],
          )
        end
      end
    end
  end

  # The split is a stacked BAR presentation: the datasets carry `stack`,
  # barPercentage and bar-only borders, and the stacking rests on the x scale's
  # `stacked: true`, which Chart.js honours for bars. A short timeframe renders
  # as a LINE chart, where all of that is ignored and the three datasets are
  # drawn over each other - an empty-looking chart. So the split follows the
  # chart TYPE, not the age of the data: a past day's splitter values are
  # complete, but there is no line rendering that could stack them.
  describe 'a single day, which renders as a line chart' do
    subject(:ids) do
      described_class.new(timeframe:).data[:datasets].pluck(:id) # rubocop:disable Rails/PluckId -- not AR
    end

    let(:seeded) { { wallbox_power: 4_000.0, wallbox_power_grid: 1_000.0 } }

    before do
      influx_batch do
        [8.hours, 12.hours, 16.hours].each do |offset|
          seeded.each do |sensor, value|
            add_influx_point(
              name: Sensor::Config.measurement(sensor),
              fields: {
                Sensor::Config.field(sensor) => value,
              },
              time: day.beginning_of_day + offset,
            )
          end
        end
      end
    end

    # Regression: enabling the split here on the grounds that the day's data is
    # complete produced a chart that rendered as nothing at all.
    context 'when it lies in the past' do
      let(:day) { 2.days.ago.to_date }
      let(:timeframe) { Timeframe.new(day.to_s) }

      it 'leaves it unsplit, having no way to stack a line chart' do
        expect(ids).to eq(['wallbox_power'])
      end
    end

    context 'when it is today' do
      let(:day) { Date.current }
      let(:timeframe) { Timeframe.new(day.to_s) }

      it 'leaves it unsplit' do
        expect(ids).to eq(['wallbox_power'])
      end
    end

    context 'when it is the "now" view' do
      let(:day) { Date.current }
      let(:timeframe) { Timeframe.new('now') }

      it 'leaves it unsplit' do
        expect(ids).to eq(['wallbox_power'])
      end
    end
  end

  # ... while a week is a bar chart, where the stack renders. This is the line
  # the rule actually draws.
  describe 'a week, which renders as a bar chart' do
    before do
      create_summary(
        date: '2025-03-04',
        values: [[:wallbox_power, :sum, 17_000], [:wallbox_power_grid, :sum, 1_000]],
      )
    end

    it 'splits it' do
      ids = described_class.new(timeframe:).data[:datasets].pluck(:id) # rubocop:disable Rails/PluckId -- not AR

      expect(ids).to eq(%i[wallbox_power wallbox_power_grid wallbox_power_pv])
    end
  end

  context 'when the power_splitter measurement has no data' do
    # Sponsor (power_splitter permitted) and grid sensor auto-configured,
    # but only the base sensor carries data -- no grid/pv split values.
    before do
      create_summary(date: '2025-03-03', values: [[:wallbox_power, :sum, 17_000]])
      create_summary(date: '2025-03-07', values: [[:wallbox_power, :sum, 15_000]])
    end

    it 'falls back to a single full-width dataset' do
      chart.data[:datasets].tap do |datasets|
        expect(datasets.length).to eq(1)

        datasets.first.tap do |wallbox_power|
          expect(wallbox_power[:id]).to eq('wallbox_power')
          # No splitter styling: stack/barPercentage are absent
          expect(wallbox_power).not_to have_key(:stack)
          expect(wallbox_power).not_to have_key(:barPercentage)
        end
      end
    end
  end
end
