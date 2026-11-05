# The live view adopts the poll interval of every stats answer, so a page opened
# in an outage of the collector returns to the rate of the data
describe 'Live poll interval' do
  before { allow(Influx::PollInterval).to receive(:current).and_return(10.seconds) }

  def get_stats(path)
    get path, headers: { 'Turbo-Frame' => 'stats' }
  end

  it 'sends the interval with the stats of the live view' do
    get_stats '/stats/house_power/now'

    expect(response.headers[LivePollInterval::HEADER]).to eq('10')
  end

  it 'sends it on the other home pages as well' do
    get_stats '/house/stats/house_power/now'

    expect(response.headers[LivePollInterval::HEADER]).to eq('10')
  end

  it 'sends nothing for a period' do
    get_stats '/stats/house_power/2026-09-18'

    expect(response.headers[LivePollInterval::HEADER]).to be_nil
  end
end
