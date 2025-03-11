describe SummaryCorrector do
  let(:corrector) { described_class.new(params) }

  describe '#adjusted' do
    subject { corrector.adjusted }

    context 'when no value is given' do
      let(:params) { {} }

      it { is_expected.to eq({}) }
    end

    context 'when PowerSplitter values are missing' do
      let(:params) do
        {
          grid_import_power: 400,
          house_power: 100,
          wallbox_power: 100,
          heatpump_power: 100,
          battery_charging_power: 100,
        }
      end

      it { is_expected.to eq({}) }
    end

    context 'when consumption value is missing - and grid is 0' do
      let(:params) { { grid_import_power: 400, heatpump_power_grid: 0 } }

      it 'does not change anything' do
        is_expected.to eq({ heatpump_power_grid: 0 })
      end
    end

    context 'when consumption value is missing - but grid is given' do
      let(:params) { { grid_import_power: 400, heatpump_power_grid: 10 } }

      it 'resets grid values' do
        is_expected.to eq({ heatpump_power_grid: 0 })
      end
    end

    context 'when grid_import_power is missing' do
      let(:params) { { grid_import_power: nil, heatpump_power_grid: 10 } }

      it 'resets grid values' do
        is_expected.to eq({ heatpump_power_grid: 0 })
      end
    end

    context 'when grid values are higher than consumption' do
      let(:params) do
        {
          grid_import_power: 400,
          #
          house_power_grid: 101,
          house_power: 100,
          #
          wallbox_power_grid: 101,
          wallbox_power: 100,
          #
          heatpump_power_grid: 101,
          heatpump_power: 100,
          #
          battery_charging_power: 101,
          battery_charging_power_grid: 100,
        }
      end

      it 'adjusts grid values' do
        is_expected.to eq(
          house_power_grid: 100,
          heatpump_power_grid: 100,
          wallbox_power_grid: 100,
          battery_charging_power_grid: 100,
        )
      end
    end

    context 'when sum of grid values > grid_import_power (which is zero)' do
      let(:params) do
        {
          grid_import_power: 0,
          #
          house_power: 100,
          house_power_grid: 10,
          #
          heatpump_power: 100,
          heatpump_power_grid: 50,
          #
          wallbox_power: 100,
          wallbox_power_grid: 20,
          #
          battery_charging_power: 100,
          battery_charging_power_grid: 30,
        }
      end

      it 'adjusts grid values' do
        is_expected.to eq(
          house_power_grid: 0,
          heatpump_power_grid: 0,
          wallbox_power_grid: 0,
          battery_charging_power_grid: 0,
        )
      end
    end

    context 'when sum of grid values > grid_import_power' do
      let(:params) do
        {
          grid_import_power: 90,
          #
          house_power: 40,
          house_power_grid: 40,
          #
          heatpump_power: 50,
          heatpump_power_grid: 50,
          #
          wallbox_power: 60,
          wallbox_power_grid: 60,
        }
      end

      it 'adjusted grid values' do
        is_expected.to eq(
          house_power_grid: 24,
          heatpump_power_grid: 30,
          wallbox_power_grid: 36,
        )
      end
    end

    context 'when sum of grid values == grid_import_power' do
      let(:params) do
        {
          grid_import_power: 90,
          #
          house_power: 30,
          house_power_grid: 30,
          #
          heatpump_power: 30,
          heatpump_power_grid: 30,
          #
          wallbox_power: 30,
          wallbox_power_grid: 30,
          #
          battery_charging_power: 0,
          battery_charging_power_grid: 0,
        }
      end

      it 'does not change anything' do
        is_expected.to eq(
          house_power_grid: 30,
          heatpump_power_grid: 30,
          wallbox_power_grid: 30,
          battery_charging_power_grid: 0,
        )
      end
    end

    context 'when sum of grid values < grid_import_power' do
      context 'when grid values cannot increased' do
        let(:params) do
          {
            grid_import_power: 100,
            house_power: 10,
            house_power_grid: 10,
            heatpump_power: 15,
            heatpump_power_grid: 15,
            wallbox_power: 20,
            wallbox_power_grid: 20,
            battery_charging_power: 25,
            battery_charging_power_grid: 25,
          }
        end

        it 'does not change anything' do
          # This is not fixable!
          is_expected.to eq(
            house_power_grid: 10,
            heatpump_power_grid: 15,
            wallbox_power_grid: 20,
            battery_charging_power_grid: 25,
          )
        end
      end

      context 'when sum of grid values == 0' do
        let(:params) do
          {
            grid_import_power: 1000,
            house_power: 100,
            house_power_grid: 0,
            heatpump_power: 400,
            heatpump_power_grid: 0,
            wallbox_power: 1000,
            wallbox_power_grid: 0,
            battery_charging_power: 100,
            battery_charging_power_grid: 0,
          }
        end

        it 'sets grid values by ratio' do
          # Ratio is 0.625
          is_expected.to eq(
            house_power_grid: 62.5,
            heatpump_power_grid: 250,
            wallbox_power_grid: 625,
            battery_charging_power_grid: 62.5,
          )
        end
      end

      context 'when sum of power values < grid_import_power' do
        let(:params) do
          {
            grid_import_power: 5000,
            house_power: 100,
            house_power_grid: 90,
            heatpump_power: 200,
            heatpump_power_grid: 190,
            wallbox_power: 300,
            wallbox_power_grid: 290,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(
            house_power_grid: 100,
            heatpump_power_grid: 200,
            wallbox_power_grid: 300,
          )
        end
      end

      context 'without wallbox and battery' do
        let(:params) do
          {
            grid_import_power: 3500,
            house_power: 1600,
            house_power_grid: 1500,
            heatpump_power: 3000,
            heatpump_power_grid: 1900,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(
            house_power_grid: 1544.1,
            heatpump_power_grid: 1955.9,
          )
        end
      end

      context 'when battery is charged from grid' do
        let(:params) do
          {
            grid_import_power: 5000,
            house_power: 1500,
            house_power_grid: 1400,
            heatpump_power: 2000,
            heatpump_power_grid: 1900,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(house_power_grid: 1500, heatpump_power_grid: 2000)
        end
      end

      context 'when only wallbox_power_grid can be adjusted' do
        let(:params) do
          {
            grid_import_power: 500,
            house_power: 100,
            house_power_grid: 100,
            heatpump_power: 200,
            heatpump_power_grid: 200,
            wallbox_power: 200,
            wallbox_power_grid: 100,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(
            house_power_grid: 100,
            heatpump_power_grid: 200,
            wallbox_power_grid: 200,
          )
        end
      end

      context 'when only heatpump_power_grid can be adjusted' do
        let(:params) do
          {
            grid_import_power: 500,
            house_power: 100,
            house_power_grid: 100,
            heatpump_power: 200,
            heatpump_power_grid: 100,
            wallbox_power: 200,
            wallbox_power_grid: 200,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(
            house_power_grid: 100,
            heatpump_power_grid: 200,
            wallbox_power_grid: 200,
          )
        end
      end

      context 'when only house_power_grid can be adjusted' do
        let(:params) do
          {
            grid_import_power: 500,
            house_power: 100,
            house_power_grid: 0,
            heatpump_power: 200,
            heatpump_power_grid: 200,
            wallbox_power: 200,
            wallbox_power_grid: 200,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(
            house_power_grid: 100,
            heatpump_power_grid: 200,
            wallbox_power_grid: 200,
          )
        end
      end

      context 'when grid values are invalid (larger as consumption)' do
        let(:params) do
          {
            grid_import_power: 800,
            battery_charging_power: 100,
            battery_charging_power_grid: 0,
            house_power: 100,
            house_power_grid: 200,
            heatpump_power: 200,
            heatpump_power_grid: 300,
            wallbox_power: 200,
            wallbox_power_grid: 300,
          }
        end

        it 'adjusts grid values' do
          is_expected.to eq(
            battery_charging_power_grid: 100,
            house_power_grid: 100,
            heatpump_power_grid: 200,
            wallbox_power_grid: 200,
          )
        end
      end
    end
  end
end
