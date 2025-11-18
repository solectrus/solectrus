describe Sensor::Definitions::GridQuote do # rubocop:disable RSpec/SpecFilePathFormat
  subject(:sensor) { described_class.new }

  describe '#calculate' do
    subject { sensor.calculate(**params) }

    context 'with normal consumption' do
      let(:params) do
        { total_consumption: 1000, grid_import_power: 300, inverter_power: 700 }
      end

      it { is_expected.to eq(30.0) }
    end

    context 'with zero consumption and production' do
      let(:params) do
        { total_consumption: 0, grid_import_power: 0, inverter_power: 100 }
      end

      it { is_expected.to eq(0) }
    end

    context 'with zero consumption and no production' do
      let(:params) do
        { total_consumption: 0, grid_import_power: 0, inverter_power: 0 }
      end

      it { is_expected.to be_nil }
    end

    context 'with missing data' do
      let(:params) do
        { total_consumption: nil, grid_import_power: nil, inverter_power: nil }
      end

      it { is_expected.to be_nil }
    end

    context 'with 100% grid import' do
      let(:params) do
        { total_consumption: 1000, grid_import_power: 1000, inverter_power: 0 }
      end

      it { is_expected.to eq(100.0) }
    end

    context 'with 0% grid import (full solar)' do
      let(:params) do
        { total_consumption: 1000, grid_import_power: 0, inverter_power: 1000 }
      end

      it { is_expected.to eq(0.0) }
    end
  end
end
