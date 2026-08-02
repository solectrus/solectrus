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

  let(:day) { Date.new(2024, 6, 14) }

  before do
    travel_to Time.zone.local(2024, 6, 15, 12, 0)

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

  def parse(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  def totals_values
    parse(
      McpServer::Tools::Totals.call(
        timeframe: day.iso8601,
        sensors: %w[autarky self_consumption_quote],
      ),
    )[:totals].to_h { |entry| [entry[:name].to_sym, entry[:value]] }
  end

  def ranking_values
    parse(
      McpServer::Tools::Ranking.call(
        timeframe: day.iso8601,
        sensors: %w[autarky self_consumption_quote],
      ),
    )[:results].to_h { |result| [result[:sensor].to_sym, result[:ranking].sole[:value]] }
  end

  # The buckets without data are null; the ones with data all carry the same
  # constant share, so a single distinct value per sensor is expected.
  def series_values
    parse(
      McpServer::Tools::Series.call(
        timeframe: day.iso8601,
        sensors: %w[autarky self_consumption_quote],
        resolution: '1h',
      ),
    )[:series].to_h do |entry|
      distinct = entry[:points].pluck(:value)
      distinct.compact!
      distinct.uniq!
      [entry[:sensor].to_sym, distinct]
    end
  end

  def current_values
    parse(
      McpServer::Tools::CurrentValues.call(
        sensors: %w[autarky self_consumption_quote],
      ),
    )[:values].to_h { |entry| [entry[:name].to_sym, entry[:value]] }
  end

  it 'reports the same percentage in get_totals and get_ranking' do
    expected = { autarky: expected_autarky, self_consumption_quote: expected_quote }

    expect(totals_values).to eq(expected)
    expect(ranking_values).to eq(expected)
  end

  it 'reports the same percentage in get_series and get_current_values' do
    expect(series_values).to eq(
      autarky: [expected_autarky],
      self_consumption_quote: [expected_quote],
    )
    expect(current_values).to eq(
      autarky: expected_autarky,
      self_consumption_quote: expected_quote,
    )
  end

  it 'agrees across all four tools' do
    expect(
      [
        totals_values,
        ranking_values,
        series_values.transform_values(&:sole),
        current_values,
      ].uniq,
    ).to have_attributes(size: 1)
  end
end
