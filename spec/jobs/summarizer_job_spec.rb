describe 'SummarizerJob' do
  subject(:job) { SummarizerJob.new }

  before do
    allow(Queries::InfluxSum).to receive(:new).and_return(
      double(
        Queries::InfluxSum,
        grid_import_power: 100,
        #
        inverter_power_1: 210,
        inverter_power_2: 40,
        inverter_power_forecast: 30,
        house_power: 200,
        heatpump_power: 50,
        grid_export_power: 50,
        battery_charging_power: 10,
        battery_discharging_power: 20,
        wallbox_power: 30,
        custom_power_01: 10,
        custom_power_02: 20,
        custom_power_03: nil,
        custom_power_04: nil,
        custom_power_05: nil,
        custom_power_06: 30,
        custom_power_07: nil,
        custom_power_08: 40,
        custom_power_09: 50,
        custom_power_10: nil,
        custom_power_11: nil,
        custom_power_12: nil,
        custom_power_13: nil,
        custom_power_14: nil,
        custom_power_15: nil,
        custom_power_16: nil,
        custom_power_17: nil,
        custom_power_18: nil,
        custom_power_19: nil,
        custom_power_20: 60,
        #
        house_power_grid: 100,
        wallbox_power_grid: 20,
        heatpump_power_grid: 30,
        battery_charging_power_grid: 10,
        custom_power_01_grid: 10,
        custom_power_02_grid: 20,
        custom_power_03_grid: nil,
        custom_power_04_grid: nil,
        custom_power_05_grid: nil,
        custom_power_06_grid: 30,
        custom_power_07_grid: nil,
        custom_power_08_grid: 40,
        custom_power_09_grid: 50,
        custom_power_10_grid: nil,
        custom_power_11_grid: nil,
        custom_power_12_grid: nil,
        custom_power_13_grid: nil,
        custom_power_14_grid: nil,
        custom_power_15_grid: nil,
        custom_power_16_grid: nil,
        custom_power_17_grid: nil,
        custom_power_18_grid: nil,
        custom_power_19_grid: nil,
        custom_power_20_grid: 80,
      ),
    )

    allow(Queries::InfluxAggregation).to receive(:new).and_return(
      double(
        Queries::InfluxAggregation,
        max_battery_charging_power: 10,
        max_battery_discharging_power: 20,
        max_battery_soc: 30,
        max_car_battery_soc: 40,
        max_case_temp: 50,
        max_grid_export_power: 60,
        max_grid_import_power: 70,
        max_heatpump_power: 80,
        max_house_power: 90,
        max_inverter_power_1: 100,
        max_inverter_power_2: 50,
        max_wallbox_power: 110,
        #
        min_battery_soc: 30,
        min_car_battery_soc: 40,
        min_case_temp: 50,
        #
        mean_battery_soc: 30,
        mean_car_battery_soc: 40,
        mean_case_temp: 50,
      ),
    )
  end

  describe '#perform' do
    subject(:perform) { job.perform(date) }

    context 'when no summary exists for the given date' do
      let(:date) { Date.current }

      let(:summary) { Summary.last }

      it 'creates Summary' do
        expect { perform }.to change(Summary, :count).by(1)
      end

      it 'creates SummaryValues' do
        expect { perform }.to change(SummaryValue, :count).by(44)
      end

      it 'corrects values when needed' do
        perform

        # Corrected
        expect(value_for(:house_power_grid)).to eq(62.5) # instead of 100
        expect(value_for(:wallbox_power_grid)).to eq(12.5) # instead of 20
        expect(value_for(:heatpump_power_grid)).to eq(18.8) # instead of 30
        expect(value_for(:battery_charging_power_grid)).to eq(6.3) # instead of 10
        expect(value_for(:custom_power_20_grid)).to eq(60) # instead of 80

        # Not changed
        expect(value_for(:custom_power_01_grid)).to eq(10)
        expect(value_for(:custom_power_02_grid)).to eq(20)
        expect(value_for(:custom_power_06_grid)).to eq(30)
        expect(value_for(:custom_power_08_grid)).to eq(40)
        expect(value_for(:custom_power_09_grid)).to eq(50)

        expect(value_for(:inverter_power_1)).to eq(210)
        expect(value_for(:inverter_power_2)).to eq(40)
        expect(value_for(:inverter_power_forecast)).to eq(30)
        expect(value_for(:house_power)).to eq(200)
        expect(value_for(:grid_import_power)).to eq(100)
        expect(value_for(:grid_export_power)).to eq(50)
      end

      private

      def value_for(field, aggregation: 'sum')
        summary.values.find_by(field:, aggregation:).value
      end
    end

    context 'when fresh summary from today exists' do
      let(:date) { Date.current }

      let!(:summary) { Summary.create!(date:, updated_at: 1.minute.ago) }

      it 'does not create Summary' do
        expect { perform }.not_to change(Summary, :count)
      end

      it 'updates Summary' do
        expect { perform }.to(change { summary.reload.updated_at })
      end
    end

    context 'when fresh summary from the past exists' do
      let(:date) { Date.yesterday }

      let!(:summary) { Summary.create!(date:, updated_at: 1.minute.ago) }

      it 'does not create Summary' do
        expect { perform }.not_to change(Summary, :count)
      end

      it 'does not update Summary' do
        expect { perform }.not_to(change { summary.reload.updated_at })
      end
    end

    context 'when stale summary already exists' do
      let(:date) { Date.yesterday }

      let!(:summary) { Summary.create!(date:, updated_at: date.middle_of_day) }

      it 'does not create Summary' do
        expect { perform }.not_to change(Summary, :count)
      end

      it 'updates Summary' do
        expect { perform }.to(change { summary.reload.updated_at })
      end
    end
  end
end
