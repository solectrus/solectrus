describe Calculator::QuerySql do
  subject(:query_sql) { described_class.new(from:, to:) }

  let(:from) { '2022-11-01'.to_date }
  let(:to) { '2022-11-02'.to_date }

  before do
    # Two days of data with the same values
    (from..to).each do |date|
      Summary.create!(
        date:,
        sum_inverter_power: 1,
        sum_inverter_power_forecast: 2,
        sum_house_power: 3,
        sum_house_power_grid: 4,
        sum_wallbox_power: 5,
        sum_wallbox_power_grid: 6,
        sum_heatpump_power: 7,
        sum_heatpump_power_grid: 8,
        sum_grid_import_power: 9,
        sum_grid_export_power: 10,
        sum_battery_charging_power: 11,
        sum_battery_discharging_power: 12,
        updated_at: date.middle_of_day,
      )
    end
  end

  it 'returns the correct values' do
    expect(query_sql.inverter_power).to eq(2)
    expect(query_sql.inverter_power_forecast).to eq(4)
    expect(query_sql.house_power).to eq(6)
    expect(query_sql.house_power_grid).to eq(8)
    expect(query_sql.wallbox_power).to eq(10)
    expect(query_sql.wallbox_power_grid).to eq(12)
    expect(query_sql.heatpump_power).to eq(14)
    expect(query_sql.heatpump_power_grid).to eq(16)
    expect(query_sql.grid_import_power).to eq(18)
    expect(query_sql.grid_export_power).to eq(20)
    expect(query_sql.battery_charging_power).to eq(22)
    expect(query_sql.battery_discharging_power).to eq(24)

    expect(query_sql.time).to eq(to.middle_of_day)
  end
end
