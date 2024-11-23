describe Calculator::PowerSplitterCorrector do
  subject(:adjusted_grid_power) do
    {
      house_power_grid: corrector.adjusted_house_power_grid,
      heatpump_power_grid: corrector.adjusted_heatpump_power_grid,
      wallbox_power_grid: corrector.adjusted_wallbox_power_grid,
    }
  end

  let(:corrector) { described_class.new(params) }

  context 'when all values are missing' do
    let(:params) { {} }

    it do
      is_expected.to eq(
        house_power_grid: nil,
        heatpump_power_grid: nil,
        wallbox_power_grid: nil,
      )
    end
  end

  context 'when PowerSplitter values are missing' do
    let(:params) do
      {
        grid_import_power: 300,
        house_power: 100,
        wallbox_power: 100,
        heatpump_power: 100,
      }
    end

    it do
      is_expected.to eq(
        house_power_grid: nil,
        heatpump_power_grid: nil,
        wallbox_power_grid: nil,
      )
    end
  end

  context 'when PowerSplitter values are invalid' do
    let(:params) do
      {
        grid_import_power: 300,
        house_power_grid: 101,
        house_power: 100,
        wallbox_power_grid: 101,
        wallbox_power: 100,
        heatpump_power_grid: 101,
        heatpump_power: 100,
      }
    end

    it do
      is_expected.to eq(
        house_power_grid: 100,
        heatpump_power_grid: 100,
        wallbox_power_grid: 100,
      )
    end
  end

  context 'when grid_import_power is 0' do
    let(:params) do
      {
        grid_import_power: 0,
        house_power: 100,
        house_power_grid: 0,
        heatpump_power: 100,
        heatpump_power_grid: 0,
        wallbox_power: 100,
        wallbox_power_grid: 0,
      }
    end

    it do
      is_expected.to eq(
        house_power_grid: 0,
        heatpump_power_grid: 0,
        wallbox_power_grid: 0,
      )
    end
  end

  context 'when grid total == grid_import_power' do
    let(:params) do
      {
        grid_import_power: 90,
        house_power: 30,
        house_power_grid: 30,
        heatpump_power: 30,
        heatpump_power_grid: 30,
        wallbox_power: 30,
        wallbox_power_grid: 30,
      }
    end

    it do
      is_expected.to eq(
        house_power_grid: 30,
        heatpump_power_grid: 30,
        wallbox_power_grid: 30,
      )
    end
  end

  context 'when grid total < grid_import_power' do
    context 'when power total == 0' do
      let(:params) do
        {
          grid_import_power: 100,
          house_power: 0,
          house_power_grid: 0,
          heatpump_power: 0,
          heatpump_power_grid: 0,
          wallbox_power: 0,
          wallbox_power_grid: 0,
        }
      end

      it do
        is_expected.to eq(
          house_power_grid: 0,
          heatpump_power_grid: 0,
          wallbox_power_grid: 0,
        )
      end
    end

    context 'when total power == grid_import_power' do
      let(:params) do
        {
          grid_import_power: 990,
          house_power: 330,
          house_power_grid: 0,
          heatpump_power: 330,
          heatpump_power_grid: 0,
          wallbox_power: 330,
          wallbox_power_grid: 0,
        }
      end

      it do
        is_expected.to eq(
          house_power_grid: 330,
          heatpump_power_grid: 330,
          wallbox_power_grid: 330,
        )
      end
    end

    context 'when total power < grid_import_power' do
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

      it do
        is_expected.to eq(
          house_power_grid: 100,
          heatpump_power_grid: 200,
          wallbox_power_grid: 300,
        )
      end
    end

    context 'when wallbox is missing' do
      let(:params) do
        {
          grid_import_power: 3519,
          house_power: 1613,
          house_power_grid: 1516,
          heatpump_power: 1990,
          heatpump_power_grid: 1890,
        }
        # Missing: 3519 - (1516 + 1890) = 113
      end

      it do
        is_expected.to eq(
          house_power_grid: 1558,
          heatpump_power_grid: 1961,
          wallbox_power_grid: nil,
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

      it do
        is_expected.to eq(
          house_power_grid: 1500,
          heatpump_power_grid: 2000,
          wallbox_power_grid: nil,
        )
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

      it do
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

      it do
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

      it do
        is_expected.to eq(
          house_power_grid: 100,
          heatpump_power_grid: 200,
          wallbox_power_grid: 200,
        )
      end
    end
  end
end
