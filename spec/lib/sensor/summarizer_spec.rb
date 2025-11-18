describe Sensor::Summarizer do
  subject(:summarizer) { described_class.new(date) }

  before do
    stub_feature(:power_splitter, :heatpump, :car)

    # Add prices for calculated sensors
    Price.create!(name: :electricity, starts_at: 1.year.ago, value: 0.25)
    Price.create!(name: :feed_in, starts_at: 1.year.ago, value: 0.08)

    raw_data = {
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
      #
      heatpump_heating_power: 200,
      inverter_power: 250,
    }

    allow(Sensor::Query::Helpers::Influx::Integral).to receive(:new).and_return(
      instance_double(
        Sensor::Query::Helpers::Influx::Integral,
        call: double('Sensor::Data::Single', raw_data),
      ),
    )

    aggregation_raw_data = {
      %i[battery_charging_power max] => 10,
      %i[battery_discharging_power max] => 20,
      %i[battery_soc max] => 30,
      %i[battery_soc min] => 30,
      %i[battery_soc avg] => 30,
      %i[car_battery_soc max] => 40,
      %i[car_battery_soc min] => 40,
      %i[car_battery_soc avg] => 40,
      %i[case_temp max] => 50,
      %i[case_temp min] => 50,
      %i[case_temp avg] => 50,
      %i[grid_export_power max] => 60,
      %i[grid_import_power max] => 70,
      %i[heatpump_power max] => 80,
      %i[house_power max] => 90,
      %i[inverter_power_1 max] => 100,
      %i[inverter_power_2 max] => 50,
      %i[wallbox_power max] => 110,
      %i[inverter_power max] => 260,
      %i[outdoor_temp max] => 40,
      %i[outdoor_temp min] => 20,
      %i[outdoor_temp avg] => 30,
      %i[heatpump_tank_temp max] => 60,
      %i[heatpump_tank_temp min] => 33,
      %i[heatpump_tank_temp avg] => 40,
    }

    allow(Sensor::Query::Helpers::Influx::Aggregation).to receive(:new).and_return(
      instance_double(
        Sensor::Query::Helpers::Influx::Aggregation,
        call:
          Sensor::Data::Single.new(
            aggregation_raw_data,
            timeframe: Timeframe.now,
          ),
      ),
    )
  end

  describe '.call' do
    context 'with Date parameter' do
      subject(:call) { described_class.call(date) }

      let(:date) { Date.current }
      let(:summarizer_instance) { instance_double(described_class) }

      before do
        allow(described_class).to receive(:new).with(date).and_return(
          summarizer_instance,
        )
        allow(summarizer_instance).to receive(:call)
      end

      it 'creates and calls instance with the given date' do
        call

        expect(described_class).to have_received(:new).with(date)
        expect(summarizer_instance).to have_received(:call)
      end
    end

    context 'with Timeframe parameter' do
      let(:timeframe) { Timeframe.new('2023-01-02') }
      let(:dates) { [Date.parse('2023-01-01'), Date.parse('2023-01-02')] }
      let(:summarizer_instance) { instance_double(described_class, call: nil) }

      before do
        allow(Summary).to receive(:missing_or_stale_days).and_return(dates)
        allow(described_class).to receive(:new).and_return(summarizer_instance)
      end

      it 'calls Summary.missing_or_stale_days with correct parameters' do
        described_class.call(timeframe)

        expect(Summary).to have_received(:missing_or_stale_days).with(
          from: timeframe.effective_beginning_date,
          to: timeframe.effective_ending_date,
        )
      end

      it 'creates instance for each date and calls it' do
        described_class.call(timeframe)

        expect(described_class).to have_received(:new).with(dates.first)
        expect(described_class).to have_received(:new).with(dates.second)
        expect(summarizer_instance).to have_received(:call).twice
      end

      it 'returns count of processed dates' do
        expect(described_class.call(timeframe)).to eq(2)
      end
    end

    context 'with invalid parameter' do
      it 'raises ArgumentError when parameter is neither Date nor Timeframe' do
        expect do
          described_class.call('invalid')
        end.to raise_error(
          ArgumentError,
          'Expected Date or Timeframe, got String',
        )
      end

      it 'raises ArgumentError when timeframe is now' do
        now_timeframe = Timeframe.now

        expect { described_class.call(now_timeframe) }.to raise_error(
          ArgumentError,
        )
      end
    end
  end

  describe '#call' do
    subject(:call) { summarizer.call }

    context 'when no summary exists for the given date' do
      let(:date) { Date.current }
      let(:summary) { Summary.last }

      it 'initializes with date and timeframe' do
        expect(summarizer.date).to eq(date)
        expect(summarizer.timeframe).to be_a(Timeframe)
      end

      it 'creates Summary' do
        expect { call }.to change(Summary, :count).from(0).to(1)
      end

      it 'creates SummaryValues' do
        expect { call }.to change(SummaryValue, :count).from(0).to(53)

        expect(summary.values.pluck(:field, :aggregation)).to contain_exactly(
          %w[battery_charging_power max],
          %w[battery_charging_power sum],
          %w[battery_charging_power_grid sum],
          %w[battery_discharging_power max],
          %w[battery_discharging_power sum],
          %w[battery_soc avg],
          %w[battery_soc max],
          %w[battery_soc min],
          %w[car_battery_soc avg],
          %w[car_battery_soc max],
          %w[car_battery_soc min],
          %w[case_temp avg],
          %w[case_temp max],
          %w[case_temp min],
          %w[custom_power_01 sum],
          %w[custom_power_01_grid sum],
          %w[custom_power_02 sum],
          %w[custom_power_02_grid sum],
          %w[custom_power_06 sum],
          %w[custom_power_06_grid sum],
          %w[custom_power_08 sum],
          %w[custom_power_08_grid sum],
          %w[custom_power_09 sum],
          %w[custom_power_09_grid sum],
          %w[custom_power_20 sum],
          %w[custom_power_20_grid sum],
          %w[grid_export_power max],
          %w[grid_export_power sum],
          %w[grid_import_power max],
          %w[grid_import_power sum],
          %w[heatpump_heating_power sum],
          %w[heatpump_power max],
          %w[heatpump_power sum],
          %w[heatpump_power_grid sum],
          %w[heatpump_tank_temp avg],
          %w[heatpump_tank_temp max],
          %w[heatpump_tank_temp min],
          %w[house_power max],
          %w[house_power sum],
          %w[house_power_grid sum],
          %w[inverter_power max],
          %w[inverter_power sum],
          %w[inverter_power_1 max],
          %w[inverter_power_1 sum],
          %w[inverter_power_2 max],
          %w[inverter_power_2 sum],
          %w[inverter_power_forecast sum],
          %w[outdoor_temp avg],
          %w[outdoor_temp max],
          %w[outdoor_temp min],
          %w[wallbox_power max],
          %w[wallbox_power sum],
          %w[wallbox_power_grid sum],
        )
      end

      it 'corrects values when needed' do
        call

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
        expect(value_for(:heatpump_power)).to eq(50)
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
        expect { call }.not_to change(Summary, :count)
      end

      it 'updates Summary' do
        expect { call }.to(change { summary.reload.updated_at })
      end
    end

    context 'when fresh summary from the past exists' do
      let(:date) { Date.yesterday }

      let!(:summary) { Summary.create!(date:, updated_at: 1.minute.ago) }

      it 'does not create Summary' do
        expect { call }.not_to change(Summary, :count)
      end

      it 'does not update Summary' do
        expect { call }.not_to(change { summary.reload.updated_at })
      end
    end

    context 'when stale summary already exists' do
      let(:date) { Date.yesterday }

      let!(:summary) { Summary.create!(date:, updated_at: date.middle_of_day) }

      it 'does not create Summary' do
        expect { call }.not_to change(Summary, :count)
      end

      it 'updates Summary' do
        expect { call }.to(change { summary.reload.updated_at })
      end
    end
  end
end
