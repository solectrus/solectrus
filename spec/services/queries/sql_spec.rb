describe Queries::Sql do
  subject(:query_sql) { described_class.new(from:, to:, calculations:) }

  let(:from) { '2022-11-01'.to_date }
  let(:to) { '2022-11-02'.to_date }

  before do
    create_summary(
      date: from,
      updated_at: from.middle_of_day,
      values: [
        [:inverter_power, :sum, 1],
        [:inverter_power_forecast, :sum, 2],
        [:house_power, :sum, 3],
        [:house_power_grid, :sum, 4],
        [:wallbox_power, :sum, 5],
        [:wallbox_power_grid, :sum, 6],
        [:heatpump_power, :sum, 7],
        [:heatpump_power_grid, :sum, 8],
        [:grid_import_power, :sum, 9],
        [:grid_export_power, :sum, 10],
        [:battery_charging_power, :sum, 11],
        [:battery_discharging_power, :sum, 12],
      ],
    )

    create_summary(
      date: to,
      updated_at: to.middle_of_day,
      values: [
        [:inverter_power, :sum, 1],
        [:inverter_power_forecast, :sum, 2],
        [:house_power, :sum, 3],
        [:house_power_grid, :sum, 4],
        [:wallbox_power, :sum, 5],
        [:wallbox_power_grid, :sum, 6],
        [:heatpump_power, :sum, 7],
        [:heatpump_power_grid, :sum, 8],
        [:grid_import_power, :sum, 9],
        [:grid_export_power, :sum, 10],
        [:battery_charging_power, :sum, 11],
        [:battery_discharging_power, :sum, 12],
      ],
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
  end
end
