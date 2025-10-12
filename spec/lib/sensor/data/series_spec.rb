describe Sensor::Data::Series do
  subject(:data) { described_class.new(series_data, timeframe:) }

  let(:timeframe) { Timeframe.new('2025') }

  describe 'initialization' do
    it 'accepts Hash as series_data' do
      expect { described_class.new({}, timeframe:) }.not_to raise_error
    end

    it 'rejects Array as series_data' do
      expect { described_class.new([], timeframe:) }.to raise_error(
        ArgumentError,
        'Series data must be a Hash with sensor keys',
      )
    end

    it 'rejects invalid series_data types' do
      expect { described_class.new('invalid', timeframe:) }.to raise_error(
        ArgumentError,
        'Series data must be a Hash with sensor keys',
      )
    end

    describe 'key format validation' do
      it 'accepts 3-element array keys' do
        series_data = {
          %i[house_power sum sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect do
          described_class.new(series_data, timeframe:)
        end.not_to raise_error
      end

      it 'rejects non-array keys' do
        series_data = { house_power: { Date.new(2025, 1, 1) => 1000.0 } }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Invalid series key format.*Must be Array/,
        )
      end

      it 'rejects array keys with wrong length' do
        series_data = {
          %i[house_power sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Series key must be Array with 3 elements/,
        )
      end

      it 'rejects non-symbol sensor names' do
        series_data = {
          ['house_power', :sum, :sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Sensor name must be a Symbol/,
        )
      end

      it 'rejects invalid aggregation types' do
        series_data = {
          %i[house_power invalid sum] => {
            Date.new(2025, 1, 1) => 1000.0,
          },
        }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Invalid aggregation: :invalid/,
        )
      end

      it 'rejects non-Hash time data' do
        series_data = { %i[house_power sum sum] => 'not a hash' }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Time data.*must be a Hash/,
        )
      end

      it 'rejects non-Date time keys' do
        series_data = { %i[house_power sum sum] => { '2025-01-01' => 1000.0 } }
        expect { described_class.new(series_data, timeframe:) }.to raise_error(
          ArgumentError,
          /Time keys must be Date or Time objects/,
        )
      end
    end
  end

  describe 'Use case 4: Series' do
    let(:series_data) do
      {
        %i[house_power sum sum] => {
          Date.new(2025, 1, 1) => 3750.0,
          Date.new(2025, 2, 1) => 3400.0,
          Date.new(2025, 3, 1) => 3200.0,
        },
        %i[case_temp avg min] => {
          Date.new(2025, 1, 1) => 20,
          Date.new(2025, 2, 1) => 24,
          Date.new(2025, 3, 1) => 25,
        },
        %i[case_temp avg max] => {
          Date.new(2025, 1, 1) => 22,
          Date.new(2025, 2, 1) => 26,
          Date.new(2025, 3, 1) => 27,
        },
      }
    end

    it 'requires parameters for series data access' do
      expect { data.house_power }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: house_power\(:sum, :sum\)/,
      )
      expect { data.case_temp }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: case_temp\(:avg, :min\), case_temp\(:avg, :max\)/,
      )
    end

    it 'supports hash return format for method access' do
      expect(data.house_power(:sum, :sum)).to eq(
        {
          Date.new(2025, 1, 1) => 3750.0,
          Date.new(2025, 2, 1) => 3400.0,
          Date.new(2025, 3, 1) => 3200.0,
        },
      )

      expect(data.case_temp(:avg, :min)).to eq(
        {
          Date.new(2025, 1, 1) => 20.0,
          Date.new(2025, 2, 1) => 24.0,
          Date.new(2025, 3, 1) => 25.0,
        },
      )
    end

    it 'raises exception for non-existent aggregation combinations' do
      expect { data.house_power(:avg, :min) }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: house_power\(:sum, :sum\)/,
      )
      expect { data.case_temp(:sum, :sum) }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: case_temp\(:avg, :min\), case_temp\(:avg, :max\)/,
      )
    end

    it 'supports empty time series Hash (different from non-existent key)' do
      empty_series_data = {
        %i[house_power sum sum] => {
          # Empty Hash - valid but no data
        },
        %i[case_temp avg min] => {
          Date.new(2025, 1, 1) => 20.0,
          Date.new(2025, 2, 1) => 24.0,
        },
      }
      empty_data = described_class.new(empty_series_data, timeframe:)

      # Empty Hash is valid and returns empty result
      expect(empty_data.house_power(:sum, :sum)).to eq({})
      # Non-empty data works normally
      expect(empty_data.case_temp(:avg, :min)).to be_a(Hash)
      expect(empty_data.case_temp(:avg, :min).keys.count).to eq(2)
    end

    it 'requires exactly 2 parameters for method access' do
      expect { data.house_power(:sum) }.to raise_error(ArgumentError)
      expect { data.house_power(:sum, :sum, :extra) }.to raise_error(
        ArgumentError,
      )
    end

    it 'extracts unique sensor names correctly' do
      expect(data.sensor_names).to contain_exactly(:house_power, :case_temp)
    end

    it 'is a series data type' do
      expect(data.series?).to be true
      expect(data.single?).to be false
    end
  end

  describe 'edge cases' do
    let(:series_data) { {} }

    it 'handles empty data' do
      expect(data.sensor_names).to eq([])
    end

    it 'fails for non-existent sensors' do
      expect { data.non_existent_sensor }.to raise_error(NoMethodError)
    end
  end

  describe 'empty time series' do
    let(:series_data) { { %i[house_power sum sum] => {} } }

    it 'requires parameters but returns empty hash for valid method access' do
      expect { data.house_power }.to raise_error(
        ArgumentError,
        /Series data requires exactly 2 aggregation parameters. Available: house_power\(:sum, :sum\)/,
      )
      expect(data.house_power(:sum, :sum)).to eq({})
    end
  end
end
