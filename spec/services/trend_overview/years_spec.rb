describe TrendOverview::Years do
  subject(:overview) { described_class.new(page: :balance, timeframe: Timeframe.all) }

  before do
    travel_to Date.new(2026, 3, 1)
    stub_feature(:trends)

    create_summary(date: Date.new(2023, 1, 1), values: [[:inverter_power, :sum, 8_000], [:house_power, :sum, 4_000]])
    create_summary(date: Date.new(2024, 1, 1), values: [[:inverter_power, :sum, 10_000], [:house_power, :sum, 3_000]])
    create_summary(date: Date.new(2024, 6, 1), values: [[:grid_import_power, :sum, 100]])
    create_summary(date: Date.new(2025, 1, 1), values: [[:inverter_power, :sum, 9_000], [:house_power, :sum, 3_500], [:grid_import_power, :sum, 2_000]])
    create_summary(date: Date.new(2026, 1, 1), values: [[:inverter_power, :sum, 20_000], [:house_power, :sum, 1_000], [:grid_import_power, :sum, 500]])
  end

  def row(name) = overview.rows.find { it.sensor.name == name }

  it 'has the value of each year' do
    expect(row(:inverter_power).values.compact).to eq(2023 => 8_000, 2024 => 10_000, 2025 => 9_000, 2026 => 20_000)
  end

  it 'leaves a year without a value of the sensor empty' do
    expect(row(:grid_import_power).values[2023]).to be_nil
  end

  # The installation year 2020 and the running year 2026 cover a part only
  it 'chooses the best of the complete years' do
    expect(row(:inverter_power).partial_years).to eq([2020, 2026])
    expect(row(:inverter_power).best_year).to eq(2024)
  end

  it 'chooses the lowest year where less is better' do
    expect(row(:house_power).best_year).to eq(2024)
  end

  # The grid starts in June 2024, so only 2025 is complete
  it 'counts the first year of a sensor added later as partial' do
    expect(row(:grid_import_power).partial_years).to contain_exactly(2020, 2024, 2026)
    expect(row(:grid_import_power).best_year).to be_nil
  end

  it 'has no best year for a neutral sensor' do
    sensor = Sensor::Registry[:outdoor_temp]
    row = described_class::Row.new(sensor:, values: { 2023 => 10.0, 2024 => 11.0 }, partial_years: [])

    expect(row.best_year).to be_nil
  end

  # A weighted average grouped by year, from the database: the day without
  # heat counts not at all
  it 'weights the outdoor temperature of each year by the heat' do
    stub_feature(:trends, :heatpump)
    create_summary(date: Date.new(2024, 1, 1), values: [[:outdoor_temp, :avg, 2.0], [:heatpump_heating_power, :sum, 30_000]])
    create_summary(date: Date.new(2024, 7, 1), values: [[:outdoor_temp, :avg, 20.0], [:heatpump_heating_power, :sum, 0]])
    create_summary(date: Date.new(2025, 1, 1), values: [[:outdoor_temp, :avg, 3.0], [:heatpump_heating_power, :sum, 30_000]])
    heatpump = described_class.new(page: :heatpump, timeframe: Timeframe.all)

    values = heatpump.rows.find { it.sensor.name == :outdoor_temp }.values

    expect(values.values_at(2024, 2025)).to eq([2.0, 3.0])
  end

  it 'groups the rows like the overview of a period' do
    expect(overview.groups.keys).to include(:generation, :consumption, :grid_battery)
  end
end
