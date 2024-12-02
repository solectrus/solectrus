describe Calculator::QuerySql do
  subject(:query_sql) { described_class.new(from:, to:, calculations:) }

  let(:from) { '2022-11-01'.to_date }
  let(:to) { '2022-11-02'.to_date }

  before do
    Summary.create!(
      date: from,
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
      avg_outdoor_temp: 10,
      updated_at: from.middle_of_day,
    )

    Summary.create!(
      date: to,
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
      avg_outdoor_temp: 15,
      updated_at: to.middle_of_day,
    )
  end

  context 'when sum-aggregations are given' do
    let(:calculations) do
      %i[
        sum_inverter_power_sum
        sum_inverter_power_forecast_sum
        sum_house_power_sum
        sum_house_power_grid_sum
        sum_wallbox_power_sum
        sum_wallbox_power_grid_sum
        sum_heatpump_power_sum
        sum_heatpump_power_grid_sum
        sum_grid_import_power_sum
        sum_grid_export_power_sum
        sum_battery_charging_power_sum
        sum_battery_discharging_power_sum
      ]
    end

    it 'responds to calculations' do
      calculations.each do |calculation|
        expect(query_sql).to respond_to(calculation)
      end
    end

    it 'returns the correct values' do
      expect(query_sql.sum_inverter_power_sum).to eq(2)
      expect(query_sql.sum_inverter_power_forecast_sum).to eq(4)
      expect(query_sql.sum_house_power_sum).to eq(6)
      expect(query_sql.sum_house_power_grid_sum).to eq(8)
      expect(query_sql.sum_wallbox_power_sum).to eq(10)
      expect(query_sql.sum_wallbox_power_grid_sum).to eq(12)
      expect(query_sql.sum_heatpump_power_sum).to eq(14)
      expect(query_sql.sum_heatpump_power_grid_sum).to eq(16)
      expect(query_sql.sum_grid_import_power_sum).to eq(18)
      expect(query_sql.sum_grid_export_power_sum).to eq(20)
      expect(query_sql.sum_battery_charging_power_sum).to eq(22)
      expect(query_sql.sum_battery_discharging_power_sum).to eq(24)
    end

    it 'returns maximum updated_at' do
      expect(query_sql.time).to eq(to.middle_of_day)
    end
  end

  context 'when aggregations are given' do
    let(:calculations) { [:avg_outdoor_temp_avg] }

    it 'responds to calculations' do
      calculations.each do |calculation|
        expect(query_sql).to respond_to(calculation)
      end
    end

    it 'returns the correct values' do
      expect(query_sql.avg_outdoor_temp_avg).to eq(12.5)
    end

    it 'returns maximum updated_at' do
      expect(query_sql.time).to eq(to.middle_of_day)
    end
  end
end
