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

  let(:by_quarter_path) do
    balance_charts_path(
      sensor_name: 'house_power',
      timeframe: 'all',
      compare: 'by_quarter',
    )
  end

  let(:by_season_path) do
    balance_charts_path(
      sensor_name: 'house_power',
      timeframe: 'all',
      compare: 'by_season',
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

    context 'with the comparison by quarter' do
      it 'compares the years on a category axis' do
        get_chart(by_quarter_path)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"type":"category"')
        expect(response.body).to include('"label":"2023"')
        expect(response.body).to include('"label":"2024"')
      end

      it 'keeps the comparison when the sensor selector offers another sensor' do
        get_chart(by_quarter_path)

        expect(response.body).to include('/inverter_power/all/by_quarter')
      end

      # No timeframe names a quarter, so a click leads to the three months of
      # it as a range. That page has to answer.
      it 'opens the quarter a bar was aimed at' do
        get_chart(by_quarter_path)

        expect(response.body).to include(
          '/house_power/2023-04-01..2023-06-30',
        )

        get balance_home_path(
              sensor_name: 'house_power',
              timeframe: '2023-04-01..2023-06-30',
            )

        expect(response).to have_http_status(:ok)
      end
    end

    context 'with the comparison by season' do
      it 'compares the years on a category axis' do
        get_chart(by_season_path)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('"type":"category"')
        expect(response.body).to include('"label":"2023"')
        expect(response.body).to include('"label":"2024"')
      end

      it 'keeps the comparison when the sensor selector offers another sensor' do
        get_chart(by_season_path)

        expect(response.body).to include('/inverter_power/all/by_season')
      end

      # A season is a range as well, and a winter runs over the turn of the
      # year. That page has to answer too.
      it 'opens the season a bar was aimed at' do
        create_summary(
          date: Date.new(2023, 12, 10),
          values: [[:house_power, :sum, 500.0]],
        )

        get_chart(by_season_path)

        expect(response.body).to include(
          '/house_power/2023-12-01..2024-02-29',
        )

        get balance_home_path(
              sensor_name: 'house_power',
              timeframe: '2023-12-01..2024-02-29',
            )

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
