# The overview of the whole time (TrendOverview::Years)
describe TrendOverview::Component, type: :component do
  subject(:page) { render_inline(described_class.new(overview:)) }

  let(:overview) do
    instance_double(TrendOverview::Years, groups: { generation: [years_row] }, page: :balance, timeframe: Timeframe.all, link_params: {})
  end

  let(:years_row) { TrendOverview::Years::Row.new(sensor: Sensor::Registry[:inverter_power], values:, partial_years: []) }
  let(:values) { { 2024 => 5_000.0, 2025 => 10_000.0 } }

  # A year beside the chevron would read like a link to that year
  it 'shows the years in place of the change, with no figure' do
    expect(page.css('.trend-overview-years > span').size).to eq(2)
    expect(page.css('.trend-overview-track, .trend-overview-value')).to be_empty
    expect(page.at_css('.sr-only').text).to eq('Best year 2025')
  end

  it 'leads to the insights of the whole time' do
    expect(page.at_css('.trend-overview-row')[:href]).to eq('/insights/inverter_power/all')
  end

  context 'with a single complete year' do
    let(:values) { { 2025 => 10_000.0 } }

    it 'names no best year' do
      expect(page.css('.sr-only')).to be_empty
    end
  end
end
