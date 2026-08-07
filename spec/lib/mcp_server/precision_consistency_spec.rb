# list_sensors publishes `conventions.precision` as a promise: a value is
# rounded by its unit and by nothing else, so the same sensor reads the same in
# every tool. The promise only holds if no layer below McpServer::Precision
# rounds first - and percentages did, in their `calculate` block, which
# get_totals, get_series and get_current_values go through while get_ranking
# computes the same share in SQL. The result was a sensor that read 81.0 in
# three tools and 80.9 in the fourth.
#
# The four tools cannot be given one literal timeframe (get_current_values
# reports an instant), so they are given one dataset instead: the same
# dependency values in the summaries and in InfluxDB, constant over the day, so
# every tool computes the same share and any disagreement is a rounding one.
#
# The subject is the agreement between four tools, not one class.
describe 'MCP precision consistency' do # rubocop:disable RSpec/DescribeClass
  let(:day) { Date.new(2024, 6, 14) }

  before { travel_to Time.zone.local(2024, 6, 15, 12, 0) }

  def parse(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  def totals_values(sensors)
    parse(
      McpServer::Tools::Totals.call(timeframe: day.iso8601, sensors:),
    )[:totals].to_h { |entry| [entry[:name].to_sym, entry[:value]] }
  end

  def ranking_values(sensors)
    parse(
      McpServer::Tools::Ranking.call(timeframe: day.iso8601, sensors:),
    )[:results].to_h { |result| [result[:sensor].to_sym, result[:ranking].sole[:value]] }
  end

  # The distinct non-null values per sensor: a bucket without data is null,
  # and the ones with data are compared as a set, so a constant day collapses
  # to one value per sensor, and a day sampled inside a single hour to that
  # hour's bucket alone.
  def series_values(sensors, resolution:)
    parse(
      McpServer::Tools::Series.call(
        timeframe: day.iso8601,
        sensors:,
        resolution:,
      ),
    )[:series].to_h do |entry|
      distinct = entry[:points].pluck(:value)
      distinct.compact!
      distinct.uniq!
      [entry[:sensor].to_sym, distinct]
    end
  end

  def current_values(sensors)
    parse(
      McpServer::Tools::CurrentValues.call(sensors:),
    )[:values].to_h { |entry| [entry[:name].to_sym, entry[:value]] }
  end

  describe 'with a day of constant values' do
    let(:sensors) { %w[autarky self_consumption_quote] }

    # Deliberately shares that survive a tenth but not a whole number: rounding
    # anywhere below the precision policy turns 80.4 into 80 and 64.6 into 65.
    #
    #   autarky = (5000 - 980) / 5000 = 80.4 %
    #   self_consumption_quote = (5000 - 1770) / 5000 = 64.6 %
    let(:expected_autarky) { 80.4 }
    let(:expected_quote) { 64.6 }

    # inverter_power is not measured directly in this configuration, so the live
    # side carries it as inverter_power_1 while the summaries store the sum.
    let(:dependencies) do
      { house_power: 5_000, grid_import_power: 980, grid_export_power: 1_770 }
    end

    before do
      create_summary(
        date: day,
        values: [
          *dependencies.map { |sensor, value| [sensor, :sum, value] },
          [:inverter_power, :sum, 5_000],
        ],
      )

      influx_batch do
        # Spread over the day for get_series, plus a fresh point so
        # get_current_values has something that is not stale.
        [day.in_time_zone + 8.hours, day.in_time_zone + 16.hours, 5.minutes.ago].each do |time|
          dependencies.merge(inverter_power_1: 5_000).each do |sensor, value|
            add_influx_point(
              name: Sensor::Config.measurement(sensor),
              fields: {
                Sensor::Config.field(sensor) => value.to_f,
              },
              time:,
            )
          end
        end
      end
    end

    it 'reports the same percentage in get_totals and get_ranking' do
      expected = { autarky: expected_autarky, self_consumption_quote: expected_quote }

      expect(totals_values(sensors)).to eq(expected)
      expect(ranking_values(sensors)).to eq(expected)
    end

    it 'reports the same percentage in get_series and get_current_values' do
      expect(series_values(sensors, resolution: '1h')).to eq(
        autarky: [expected_autarky],
        self_consumption_quote: [expected_quote],
      )
      expect(current_values(sensors)).to eq(
        autarky: expected_autarky,
        self_consumption_quote: expected_quote,
      )
    end

    it 'agrees across all four tools' do
      expect(
        [
          totals_values(sensors),
          ranking_values(sensors),
          series_values(sensors, resolution: '1h').transform_values(&:sole),
          current_values(sensors),
        ].uniq,
      ).to have_attributes(size: 1)
    end
  end

  # The agreement above rests on a day whose values never change - it has to,
  # because get_current_values reports an instant and needs something
  # comparable. But a constant day also hides the one disagreement that is not
  # a rounding one: get_totals and get_ranking derive an averaged ratio from
  # the period's ENERGIES (the summaries are time-weighted integrals), while
  # get_series derives it from a bucket's mean powers - and a Flux mean weights
  # SAMPLES, not time. The two coincide only while the sample density is even
  # across the bucket. Constant values make it even by construction.
  #
  # So this dataset makes it uneven on purpose, inside a single hour - the
  # coarsest bucket get_series offers: one sample against two. The tools then
  # part ways by 7.6 points, which is not a defect to be fixed here but the
  # documented reach of get_series - what is guarded is that each tool keeps
  # computing its OWN rule.
  describe 'with a day whose sample density is uneven' do
    # The day's true energies, as the summaries hold them: 14400 Wh consumed,
    # 2400 Wh imported.
    let(:expected_energy_ratio) { 83.3 } # (14400 - 2400) / 14400

    # The samples that reach InfluxDB, all inside the 13:00 bucket: one at
    # 200 W fully imported, two at 1000 W fully self-supplied. In an unweighted
    # mean the second value carries two thirds of the weight, so house_power
    # averages 733.3 W and grid_import_power 66.7 W.
    let(:expected_sample_ratio) { 90.9 } # (733.3 - 66.7) / 733.3

    before do
      create_summary(
        date: day,
        values: [[:house_power, :sum, 14_400], [:grid_import_power, :sum, 2_400]],
      )

      influx_batch do
        {
          0 => { house_power: 200, grid_import_power: 200 },
          20 => { house_power: 1_000, grid_import_power: 0 },
          40 => { house_power: 1_000, grid_import_power: 0 },
        }.each do |minute, values|
          values.each do |sensor, value|
            add_influx_point(
              name: Sensor::Config.measurement(sensor),
              fields: {
                Sensor::Config.field(sensor) => value.to_f,
              },
              time: day.in_time_zone + 13.hours + minute.minutes,
            )
          end
        end
      end
    end

    it 'derives the ratio from the energies in get_totals and get_ranking' do
      expect(totals_values(%w[autarky])).to eq(autarky: expected_energy_ratio)
      expect(ranking_values(%w[autarky])).to eq(autarky: expected_energy_ratio)
    end

    it 'derives the ratio from the bucket means in get_series' do
      values = series_values(%w[autarky total_consumption grid_import_power], resolution: '1h')
      consumption = values[:total_consumption].sole
      import = values[:grid_import_power].sole

      # Not a magic number: exactly the share the same response reports its own
      # mean powers to carry.
      expect(values[:autarky]).to eq([expected_sample_ratio])
      expect(
        ((consumption - import) * 100 / consumption).round(1),
      ).to eq(expected_sample_ratio)
    end
  end
end
