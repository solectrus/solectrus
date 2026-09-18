# A frame carries the data of a home page and is a request of its own, so what
# holds the page back holds the frame back as well.
describe 'Sponsored frames' do
  before { stub_feature(*features) }

  def get_frame(path)
    get path, headers: { 'Turbo-Frame' => 'chart' }
  end

  # The page itself is the feature.
  describe 'a page behind a sponsorship' do
    context 'without the feature' do
      let(:features) { [] }

      it 'answers nothing for the chart' do
        get_frame '/house/charts/custom_power_01/2026-09-18'
        expect(response).to have_http_status(:not_found)
      end

      it 'answers nothing for the stats' do
        get_frame '/house/stats/custom_power_01/2026-09-18'
        expect(response).to have_http_status(:not_found)
      end

      it 'answers nothing for the other pages behind one' do
        get_frame '/heatpump/charts/heatpump_power/2026-09-18'
        expect(response).to have_http_status(:not_found)

        get_frame '/inverter/charts/inverter_power/2026-09-18'
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with the feature' do
      let(:features) { %i[custom_consumer] }

      it 'answers the chart' do
        get_frame '/house/charts/custom_power_01/2026-09-18'
        expect(response).to have_http_status(:success)
      end
    end
  end

  # The start page is free, and so are its frames.
  describe 'a page without a sponsorship' do
    let(:features) { [] }

    it 'answers the chart' do
      get_frame '/charts/inverter_power/2026-09-18'
      expect(response).to have_http_status(:success)
    end

    it 'answers the stats' do
      get_frame '/stats/inverter_power/2026-09-18'
      expect(response).to have_http_status(:success)
    end
  end

  # A relative timeframe is a feature on every page, the free one included.
  describe 'a relative timeframe' do
    context 'without the feature' do
      let(:features) { [] }

      it 'answers nothing' do
        get_frame '/charts/inverter_power/P7D'
        expect(response).to have_http_status(:not_found)

        get_frame '/stats/inverter_power/P7D'
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'with the feature' do
      let(:features) { %i[relative_timeframe] }

      it 'answers the chart' do
        get_frame '/charts/inverter_power/P7D'
        expect(response).to have_http_status(:success)
      end
    end
  end
end
