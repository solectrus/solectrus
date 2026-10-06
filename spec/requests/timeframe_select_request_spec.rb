# The timeframe select loads the address of the page into the modal, and the
# page renders the select instead of itself (see TimeframePage::Sensor)
describe 'Timeframe select' do
  def get_select(path)
    get path, headers: { 'Turbo-Frame' => 'modal' }
  end

  it 'renders the select of the start page, with the hours' do
    get_select('/inverter_power/day')

    expect(response.body).to include('<turbo-frame id="modal"', 'data-timeframe-select--component-base-url-value="/inverter_power"')
    expect(response.body).to include('data-value="P24H"')
  end

  it 'renders the select of another home page' do
    get_select('/house/house_power/2025')

    expect(response.body).to include('data-timeframe-select--component-base-url-value="/house/house_power"')
  end
end
