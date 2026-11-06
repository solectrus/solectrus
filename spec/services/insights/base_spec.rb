describe Insights::Base do
  subject(:insight) { described_class.new(timeframe:, sensor: :inverter_power) }

  let(:timeframe) { Timeframe.new('2025-10') }

  it 'keeps the timeframe and the options' do
    expect(insight).to have_attributes(timeframe:, options: { sensor: :inverter_power })
  end

  # Each insight implements its own query
  it 'leaves #call to the subclass' do
    expect { insight.call }.to raise_error(NotImplementedError)
  end
end
