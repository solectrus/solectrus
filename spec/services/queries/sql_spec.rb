describe Queries::Sql do
  let(:query_sql) { described_class.new(calculations, from:, to:) }

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
        [:case_temp, :min, 5],
        [:case_temp, :max, 15],
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
        [:case_temp, :min, 10],
        [:case_temp, :max, 20],
      ],
    )
  end

  context 'when calculations are given' do
    let(:calculations) do
      [
        Queries::Calculation.new(:inverter_power, :sum, :sum),
        Queries::Calculation.new(:inverter_power_forecast, :sum, :sum),
        Queries::Calculation.new(:house_power, :sum, :sum),
        Queries::Calculation.new(:house_power_grid, :sum, :sum),
        Queries::Calculation.new(:wallbox_power, :sum, :sum),
        Queries::Calculation.new(:wallbox_power_grid, :sum, :sum),
        Queries::Calculation.new(:heatpump_power, :sum, :sum),
        Queries::Calculation.new(:heatpump_power_grid, :sum, :sum),
        Queries::Calculation.new(:grid_import_power, :sum, :sum),
        Queries::Calculation.new(:grid_export_power, :sum, :sum),
        Queries::Calculation.new(:battery_charging_power, :sum, :sum),
        Queries::Calculation.new(:battery_discharging_power, :sum, :sum),
        Queries::Calculation.new(:case_temp, :min, :min),
        Queries::Calculation.new(:case_temp, :max, :max),
        Queries::Calculation.new(:case_temp, :max, :avg),
      ]
    end

    describe '#value' do
      delegate :value, to: :query_sql

      it 'returns the correct values' do
        expect(value(:inverter_power, :sum, :sum)).to eq(2)
        expect(value(:inverter_power_forecast, :sum, :sum)).to eq(4)
        expect(value(:house_power, :sum, :sum)).to eq(6)
        expect(value(:house_power_grid, :sum, :sum)).to eq(8)
        expect(value(:wallbox_power, :sum, :sum)).to eq(10)
        expect(value(:wallbox_power_grid, :sum, :sum)).to eq(12)
        expect(value(:heatpump_power, :sum, :sum)).to eq(14)
        expect(value(:heatpump_power_grid, :sum, :sum)).to eq(16)
        expect(value(:grid_import_power, :sum, :sum)).to eq(18)
        expect(value(:grid_export_power, :sum, :sum)).to eq(20)
        expect(value(:battery_charging_power, :sum, :sum)).to eq(22)
        expect(value(:battery_discharging_power, :sum, :sum)).to eq(24)
        expect(value(:case_temp, :min, :min)).to eq(5)
        expect(value(:case_temp, :max, :max)).to eq(20)
        expect(value(:case_temp, :max, :avg)).to eq(17.5)
      end
    end

    describe '#to_hash' do
      subject { query_sql.to_hash }

      it do
        is_expected.to eq(
          {
            %i[inverter_power sum sum] => 2,
            %i[inverter_power_forecast sum sum] => 4,
            %i[house_power sum sum] => 6,
            %i[house_power_grid sum sum] => 8,
            %i[wallbox_power sum sum] => 10,
            %i[wallbox_power_grid sum sum] => 12,
            %i[heatpump_power sum sum] => 14,
            %i[heatpump_power_grid sum sum] => 16,
            %i[grid_import_power sum sum] => 18,
            %i[grid_export_power sum sum] => 20,
            %i[battery_charging_power sum sum] => 22,
            %i[battery_discharging_power sum sum] => 24,
            %i[case_temp min min] => 5,
            %i[case_temp max max] => 20,
            %i[case_temp max avg] => 17.5,
          },
        )
      end
    end
  end
end
