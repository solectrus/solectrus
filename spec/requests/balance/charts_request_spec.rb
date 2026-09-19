describe 'Charts' do
  def get_chart(path)
    get path, headers: { 'Turbo-Frame' => 'random-turbo-frame' }
  end

  let(:regular_path) do
    balance_charts_path(sensor_name: 'house_power', timeframe: 'all')
  end

  let(:by_month_path) do
    balance_charts_path(
      sensor_name: 'house_power',
      timeframe: 'all',
      compare: 'by_month',
    )
  end

  describe 'GET /charts' do
    before do
      create_summary(
        date: Date.new(2023, 5, 10),
        values: [[:house_power, :sum, 1000.0]],
      )
      create_summary(
        date: Date.new(2024, 5, 10),
        values: [[:house_power, :sum, 2000.0]],
      )
    end

    context 'without the year comparison' do
      it 'draws one bar per year' do
        get_chart(regular_path)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"type":"time"')
      end

      # The switch sits in the timeframe tabs, which the chart frame updates
      # along with itself.
      it 'offers the comparison, as a path rather than a query parameter' do
        get_chart(regular_path)

        expect(response.body).to include('/house_power/all/by_month')
        expect(response.body).not_to include('compare=')
      end
    end

    context 'with the year comparison' do
      it 'compares the years on a category axis' do
        get_chart(by_month_path)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"type":"category"')
      end

      it 'builds one dataset per year' do
        get_chart(by_month_path)

        expect(response.body).to include('"label":"2023"')
        expect(response.body).to include('"label":"2024"')
      end

      it 'offers the way back' do
        get_chart(by_month_path)

        expect(response.body).to include(regular_path)
      end

      it 'keeps the comparison when the sensor selector offers a sensor that can be compared' do
        get_chart(by_month_path)

        expect(response.body).to include('/inverter_power/all/by_month')
      end

      # The power balance has no value of its own, so picking it leaves the
      # comparison. That brings the stats back, which only a full load can do,
      # so the item must not swap the chart frame alone.
      it 'leaves the comparison behind for a sensor that cannot be compared' do
        get_chart(by_month_path)

        item = response.body[%r{<a[^>]*href="/power_balance/all"[^>]*>}]

        expect(item).to be_present
        expect(item).not_to include('loadChart')
      end

      # The comparison belongs to the total timeframe alone. `url_for` fills a
      # segment it is not given from the path of the current page, so a tab
      # leading away has to name it empty.
      it 'drops the comparison from the tabs of the other timeframes' do
        get_chart(by_month_path)

        year = Date.current.year

        expect(response.body).to include("/house_power/#{year}\"")
        expect(response.body).not_to include("/house_power/#{year}/by_month")
      end
    end
  end
end
