describe 'Charging sessions' do
  # The sums in the head of the list, as text
  def totals = response.parsed_body.at_css('.ui-keep-lit span.text-fg-secondary.tabular-nums').text

  before do
    login_as_admin

    # The list of the offsite sessions waits for the proposals of the build.
    # Most examples need no build (see 'the proposals').
    allow(ChargingSession::OffsiteDetection).to receive(:enabled?).and_return(false)
  end

  # The list of the charging sessions of a kind, or its sessions to review
  # alone
  def page(kind = 'wallbox', timeframe: 'all', car: nil, review: nil)
    cars_charging_sessions_path(kind:, timeframe:, car:, review:)
  end

  # The switch of the sessions to review in the head of the list
  def review_switch = response.parsed_body.at_css('.ui-keep-lit a[role="switch"]')

  let(:car) { Car.create!(id: 1, name: 'Trabant') }
  let!(:recent) do
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 2.days.ago, kwh: 10, cost: 5)
  end
  let!(:old) do
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 2.years.ago, kwh: 20, cost: 10)
  end

  def found_place
    Place.new(latitude: 51.0, longitude: 7.0, geocoding: { 'address' => { 'country_code' => 'de', 'postcode' => '12345', 'town' => 'Town', 'road' => 'Main Street' } })
  end

  def wallbox(started_at, **)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at:, ended_at: started_at + 1.hour, kwh: 7, **)
  end

  describe 'GET /cars/charging_sessions' do
    it 'redirects to the default kind and timeframe' do
      get '/cars/charging_sessions'
      expect(response).to redirect_to('/cars/charging_sessions/wallbox/all')
    end

    it 'goes back to the car page in the timeframe and with the car' do
      get '/cars/1/charging_sessions/offsite/2025'
      expect(response.body).to include('href="/cars/1/2025"')
    end

    # Today and yesterday tell where the car is (see Car::AdminOnlyDays)
    context 'with a session of yesterday' do
      before { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: Date.yesterday.in_time_zone.change(hour: 12), kwh: 40, cost: 20) }

      def note = 'Only the administrator sees the charging sessions of today and yesterday.'

      it 'leaves it out for a guest, also in the sums, with a note' do
        logout
        get page('offsite')

        expect(totals).to start_with('2 charging sessions · 30.0 kWh')
        expect(response.body).to include(note)
      end

      it 'shows it to the admin' do
        get page('offsite')

        expect(totals).to start_with('3 charging sessions · 70.0 kWh')
        expect(response.body).not_to include(note)
      end

      # The note does not tell whether such a day has a session
      it 'has no note for a guest in a list without such a day' do
        logout
        get page('offsite', timeframe: (Date.current.year - 2).to_s)

        expect(response.body).not_to include(note)
      end
    end
  end

  describe 'the list' do
    it 'lists the sessions of the kind and the timeframe' do
      get page('offsite')
      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent.started_at.iso8601, old.started_at.iso8601)

      get page('offsite', timeframe: Date.current.year.to_s)
      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end

    it 'shows the car of each session' do
      get page('offsite')
      expect(response.body).to include('Trabant')
    end

    it 'sums the sessions of the kind in its head' do
      get page('offsite')
      expect(totals).to eq('2 charging sessions · 30.0 kWh · € 15.00')
    end

    # A wallbox session without a price has no cost, so the cost of the sums
    # is a minimum
    it 'explains a cost that is a minimum' do
      allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
      wallbox(2.days.ago, car:, cost: 2)
      wallbox(1.day.ago, car:)
      get page('wallbox')

      expect(totals).to eq('2 charging sessions · 14.0 kWh · ≥ € 2.00')
      expect(response.parsed_body.at_css('.ui-keep-lit span.tabular-nums[title]')['title']).to eq(I18n.t('charging_sessions.cost_incomplete'))
    end

    # The desktop has the state of charge before and after in a column
    it 'shows the state of charge of a session' do
      allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
      wallbox(1.day.ago, car:, soc_from: 38, soc_to: 80)
      get page('wallbox')

      expect(response.body).to include('38 → 80%')
    end

    it 'renders an empty state message when no sessions match the timeframe' do
      get page('offsite', timeframe: 'day')
      expect(response.body).to include('No offsite charging sessions')
      expect(response.body).not_to include('/map"')
    end

    it 'names the car in an empty list' do
      get page('offsite', timeframe: 'day', car: 1)
      expect(response.body).to include('No offsite charging sessions of Trabant')
    end

    it 'switches between the kinds, with the car' do
      get page('offsite', timeframe: '2025', car: 1)
      expect(response.body).to include(%(href="/cars/1/charging_sessions/wallbox/2025"), %(aria-current="page" href="/cars/1/charging_sessions/offsite/2025"))
    end

    it 'offers the map of the offsite sessions' do
      get page('offsite')
      expect(response.body).to include('href="/cars/charging_sessions/offsite/all/map"')

      get page('wallbox')
      expect(response.body).not_to include('/map"')
    end

    # A phone has the sums as columns, each value above its caption
    it 'shows the sums as columns on a phone' do
      get page('offsite')
      stats = response.parsed_body.css('.ui-keep-lit .grid > div').map { |stat| stat.element_children.map { it.text.squish } }
      expect(stats).to eq([%w[2 sessions], ['30.0 kWh', 'charged'], ['15.00 €', 'cost']])
    end

    it 'offers a new offsite session' do
      get page
      expect(response.body).to include('/cars/charging_sessions/new')
    end

    it 'shows no proposal hint in the form of a new session' do
      get '/cars/charging_sessions/new', headers: { 'Turbo-Frame' => 'modal' }
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include(I18n.t('charging_sessions.proposal.form_hint'))
    end

    context 'without login' do
      before { logout }

      it 'lists the sessions without their places, their forms and the new session' do
        recent.update_columns(address: 'DE-12345 Town, Main Street 15') # rubocop:disable Rails/SkipsModelValidations
        get page('offsite')

        expect(response.body).to include(recent.started_at.iso8601)
        expect(response.body).not_to include('Main Street', '/edit', '/cars/charging_sessions/new', '/map"')
      end

      it 'loads the next page of the list' do
        get '/cars/charging_sessions/offsite/all', params: { page: 2 }, headers: { 'Turbo-Frame' => 'sessions_page_2' }
        expect(response).to have_http_status(:success)
      end

      it 'forbids the map' do
        get '/cars/charging_sessions/offsite/all/map'
        expect(response).to have_http_status(:forbidden)
      end
    end

    # Without a car, there is no car page (see Sensor::HomePage)
    context 'without a car' do
      before { Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_CAR_BATTERY_SOC')) }

      it 'redirects to the start page' do
        get '/cars/charging_sessions/offsite'
        expect(response).to redirect_to(root_path)
      end
    end

    context 'without a wallbox' do
      before { Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_WALLBOX_POWER', 'INFLUX_SENSOR_WALLBOX_CAR_CONNECTED')) }

      it 'lists the offsite sessions without a switch' do
        get page('offsite')
        expect(response.body).to include(recent.started_at.iso8601)
        expect(response.body).not_to include('/charging_sessions/wallbox/all"')
      end

      # The sessions of an earlier wallbox stay as history
      it 'keeps the switch while wallbox sessions exist' do
        wallbox(3.days.ago)
        get page('offsite')
        expect(response.body).to include('/charging_sessions/wallbox/all"')
      end
    end

    context 'with the car page switched off' do
      before { Setting.enable_car = false }

      it 'redirects to the start page' do
        get '/cars/charging_sessions/offsite'
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'the car filter' do
    let(:year) { Date.current.year }

    before do
      Sensor::Config.setup(
        ENV.to_h.merge(
          'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
          'INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer',
          'INFLUX_SENSOR_CAR_ODOMETER_3' => 'Lada:odometer',
        ),
      )
      car
      Car.create!(id: 2, name: 'Wartburg', active_until: Date.new(year - 1, 12, 31))
      Car.create!(id: 3, name: 'Lada')
    end

    after { Sensor::Config.setup(ENV) }

    it 'offers only the cars in use in the timeframe' do
      get page('offsite', timeframe: year.to_s)

      expect(response.body).to include("/cars/3/charging_sessions/offsite/#{year}")
      expect(response.body).not_to include("/cars/2/charging_sessions/offsite/#{year}")
    end

    it 'offers a sold car in a timeframe of its period' do
      get page('offsite', timeframe: (year - 1).to_s)

      expect(response.body).to include("/cars/2/charging_sessions/offsite/#{year - 1}")
    end

    it 'redirects a car outside the timeframe to "all"' do
      get page('offsite', timeframe: year.to_s, car: 2)

      expect(response).to redirect_to(page('offsite', timeframe: year.to_s))
    end

    it 'redirects a car outside the timeframe of the map to "all"' do
      get '/cars/9/charging_sessions/offsite/all/map'

      expect(response).to redirect_to('/cars/charging_sessions/offsite/all/map')
    end

    # The add button of the list passes its address, with its timeframe and its car
    describe 'in the form of a new session' do
      def new_session(timeframe: nil, car: nil)
        get '/cars/charging_sessions/new',
            params: { return_to: page('offsite', timeframe:, car:) },
            headers: { 'Turbo-Frame' => 'modal' }
      end

      def car_choices = response.parsed_body.css('select[name="charging_session[car_id]"] option')

      it 'offers the cars in use in the timeframe of the list' do
        new_session(timeframe: (year - 1).to_s)

        expect(car_choices.map(&:text)).to include('Wartburg')
      end

      it 'offers no car outside the timeframe of the list' do
        new_session(timeframe: year.to_s)

        expect(car_choices.map(&:text)).not_to include('Wartburg')
      end

      it 'selects the car of the list' do
        new_session(timeframe: year.to_s, car: '3')

        expect(car_choices.find { it['selected'] }&.text).to eq('Lada')
      end

      def date_value(name) = response.parsed_body.at_css("input[name=\"charging_session[#{name}]\"]")['value']

      it 'starts now in a list that reaches today' do
        travel_to Time.zone.local(2026, 10, 13, 9, 41, 27) do
          new_session(timeframe: '2026')
        end

        expect(date_value(:started_at)).to eq('2026-10-13T09:41:00')
        expect(date_value(:ended_at)).to be_nil
      end

      it 'starts now in a range that reaches today' do
        travel_to Time.zone.local(2026, 10, 13, 9, 41, 27) do
          new_session(timeframe: '2026-10-01..2026-10-13')
        end

        expect(date_value(:started_at)).to eq('2026-10-13T09:41:00')
      end

      it 'leaves the start empty in a past list' do
        new_session(timeframe: (year - 1).to_s)

        expect(date_value(:started_at)).to be_nil
      end

      it 'selects a car in use today when the session starts now' do
        car.update_columns(active_until: Date.new(year - 1, 12, 31)) # rubocop:disable Rails/SkipsModelValidations
        new_session(timeframe: 'all')

        expect(car_choices.find { it['selected'] }&.text).to eq('Lada')
        expect(date_value(:started_at)).to be_present
      end

      it 'leaves the start empty for a car of the list no longer in use' do
        new_session(timeframe: 'all', car: '2')

        expect(car_choices.find { it['selected'] }&.text).to eq('Wartburg')
        expect(date_value(:started_at)).to be_nil
      end
    end
  end

  describe 'the timeframe' do
    it 'keeps the chart and the kind before and after' do
      get page('offsite', timeframe: '2025')

      expect(response.body).to include('href="/cars/charging_sessions/offsite/2024"', 'href="/cars/charging_sessions/offsite/2026"')
    end
  end

  describe 'the groups' do
    def headers = response.parsed_body.css('#list h3').map { it.text.strip }

    it 'groups a long list by month' do
      get page('offsite')

      expect(headers).to eq([I18n.l(recent.date, format: :month), I18n.l(old.date, format: :month)])
    end

    it 'opens the page of a group from its header, with the car and the kind' do
      get page('offsite', car: 1)

      links = response.parsed_body.css('#list h3 a').pluck('href')
      expect(links).to eq([page('offsite', car: 1, timeframe: recent.date.strftime('%Y-%m')), page('offsite', car: 1, timeframe: old.date.strftime('%Y-%m'))])
    end

    it 'groups the list of a month by week' do
      get page('offsite', timeframe: recent.date.strftime('%Y-%m'))

      expect(headers).to eq([I18n.l(recent.date.beginning_of_week, format: :week)])
    end

    it 'groups the list of a week by day' do
      get page('offsite', timeframe: recent.date.strftime('%G-W%V'))

      expect(headers).to eq([I18n.l(recent.date, format: '%A')])
    end

    it 'gives the list of a day one group' do
      get page('offsite', timeframe: recent.date.iso8601)

      expect(headers).to eq([I18n.l(recent.date, format: '%A')])
      expect(response.parsed_body.css('#list h3 a')).to be_empty
    end

    it 'loads the next page from the list, and gives a group that goes on no second header' do
      start = 2.years.ago.beginning_of_month + 10.days
      25.times { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: start + it.hours, kwh: 1, cost: 1) }

      get page('offsite')
      expect(response.body).to include('src="/cars/charging_sessions/offsite/all?page=2')

      get '/cars/charging_sessions/offsite/all', params: { page: 2 }, headers: { 'Turbo-Frame' => 'sessions_page_2' }

      expect(response.body).to include(start.iso8601)
      expect(response.parsed_body.css('h3')).to be_empty
      # The rows of the next page lead back to the page of the charging
      expect(response.body).to include("return_to=#{CGI.escape(page('offsite'))}")
    end
  end

  describe 'the wallbox sessions' do
    def day = 3.days.ago.to_date

    let!(:unassigned) { wallbox(day.in_time_zone.change(hour: 9)) }
    let!(:guest) { wallbox(day.in_time_zone.change(hour: 14), guest: true) }

    before do
      (Date.current.beginning_of_year..Date.current).each do |date|
        Summary.create!(date:)
      end
    end

    it 'shows "all" with the guest and the open sessions, and counts the guest alone' do
      get page(timeframe: Date.current.year.to_s)

      expect(response.body).to include(unassigned.started_at.iso8601, guest.started_at.iso8601)
      expect(totals).to eq('1 charging session · 7.0 kWh')
    end

    # The row of an open session has a question mark that names the task
    it 'marks the session that is not assigned' do
      get page(timeframe: Date.current.year.to_s)

      expect(response.parsed_body.css("[role=img][title='Not assigned']")).to be_present
    end

    # A switch beside the sums shows the sessions to review alone, and the
    # sums stay
    it 'switches to the sessions to review alone and back' do
      get page(timeframe: Date.current.year.to_s)
      expect(review_switch).to have_attributes(text: include('1 not assigned'))
      expect(review_switch['aria-checked']).to eq('false')

      get review_switch['href']

      expect(response.body).to include(unassigned.started_at.iso8601, 'These wallbox sessions belong to no car or guest yet.')
      expect(response.body).not_to include(guest.started_at.iso8601)
      expect(totals).to eq('1 charging session · 7.0 kWh')
      expect(review_switch['aria-checked']).to eq('true')
      expect(review_switch['href']).to eq(page(timeframe: Date.current.year.to_s))
    end

    it 'says that nothing is left to review' do
      unassigned.update!(guest: true)
      get page(timeframe: Date.current.year.to_s, review: '1')

      expect(response.body).to include('All assigned')
      expect(review_switch['aria-checked']).to eq('true')
    end

    # A session that is not assigned belongs to no car, so it can be the
    # charge of any car. Its list is the one of "all".
    it 'names the sessions that are not assigned to one car, in the list of all' do
      get page(timeframe: Date.current.year.to_s, car: car.id)
      expect(review_switch.text).to include('1 not assigned')
      expect(review_switch['href']).to eq(page(timeframe: Date.current.year.to_s, review: '1'))

      get page(timeframe: Date.current.year.to_s, car: car.id, review: '1')
      expect(response).to redirect_to(page(timeframe: Date.current.year.to_s, review: '1'))
    end

    it 'has no switch without a session to review' do
      unassigned.update!(guest: true)
      get page(timeframe: Date.current.year.to_s)

      expect(review_switch).to be_nil
    end

    it 'has the sessions to review for the admin only' do
      logout
      get page(timeframe: Date.current.year.to_s, review: '1')

      expect(review_switch).to be_nil
      expect(response.body).to include(guest.started_at.iso8601)
    end

    it 'shows the open sessions only to the admin' do
      logout
      get page(timeframe: Date.current.year.to_s)

      expect(response.body).to include(guest.started_at.iso8601)
      expect(response.body).not_to include(unassigned.started_at.iso8601, 'not assigned')
    end

    it 'shows the PV share of each session' do
      unassigned.update!(kwh_grid: 1.75)
      guest.update!(kwh_grid: 7)

      get page(timeframe: Date.current.year.to_s)

      expect(response.body).to include('>75%<', '>0%<')
    end

    it 'shows no PV share without the grid share of a session' do
      get page(timeframe: Date.current.year.to_s)

      expect(response.body).not_to include('>75%<')
    end

    it 'lists the guest sessions of the guest' do
      get page(timeframe: Date.current.year.to_s, car: 'guest')

      expect(response.body).to include(guest.started_at.iso8601)
      expect(response.body).not_to include(unassigned.started_at.iso8601)
    end

    # The car page selects the guest, but no session that is not assigned
    it 'links the day of a guest session to the car page of the guest' do
      get page(timeframe: Date.current.year.to_s)

      expect(response.body).to include(%(href="/cars/guest/#{day.iso8601}"), %(href="/wallbox_power/#{day.iso8601}"))
    end

    it 'goes back to the overview of the guest' do
      get page(car: 'guest')

      expect(response.body).to include(%(href="/cars/guest/all"))
    end

    # A guest charges at the wallbox alone (see ChargingSession#guest_without_car)
    it 'gives the guest the wallbox sessions alone, without a new session' do
      get page('offsite', timeframe: Date.current.year.to_s, car: 'guest')
      expect(response).to redirect_to(page('wallbox', timeframe: Date.current.year.to_s, car: 'guest'))

      follow_redirect!
      expect(response.body).not_to include('charging_sessions/offsite', 'charging_sessions/new')
    end

    it 'names the guest in an empty list, without sums' do
      get page(timeframe: 'day', car: 'guest')

      expect(response.body).to include('No guest charging sessions')
      expect(response.body).not_to include('0 charging sessions')
    end

    it 'assigns a session to a car' do
      patch "/cars/charging_sessions/#{unassigned.id}",
            params: { charging_session: { car_id: car.id, note: 'Trip' } },
            as: :turbo_stream

      expect(unassigned.reload).to have_attributes(car_id: car.id, guest: false, note: 'Trip', assigned_manually: true)
    end

    it 'keeps the choice of the detection when only the note changes' do
      patch "/cars/charging_sessions/#{unassigned.id}",
            params: { charging_session: { car_id: '', note: 'Unknown' } },
            as: :turbo_stream

      expect(unassigned.reload).to have_attributes(car_id: nil, note: 'Unknown', assigned_manually: false)
    end

    it 'says in the form who chose the car' do
      get "/cars/charging_sessions/#{unassigned.id}/edit"

      expect(response.body).to include(I18n.t('charging_sessions.form.assigned_by_detection'))
    end

    it 'marks a session as a guest charge and keeps its energy' do
      patch "/cars/charging_sessions/#{unassigned.id}",
            params: { charging_session: { car_id: 'guest', kwh: 99 } },
            as: :turbo_stream

      expect(unassigned.reload).to have_attributes(car_id: nil, guest: true, kwh: 7, assigned_manually: true)
    end

    describe 'a charge over midnight' do
      # The detection cuts the charge at midnight: [evening, morning]
      def charge
        midnight = day.in_time_zone.beginning_of_day
        [wallbox(midnight - 1.hour, ended_at: midnight - 1.second, car:), wallbox(midnight, car:)]
      end

      it 'shows one charge and counts it once' do
        evening, morning = charge

        get page(car: car.id, timeframe: "#{day - 1}..#{day}")

        expect(response.body).to include(evening.started_at.iso8601)
        expect(totals).to start_with('1 charging session · 14.0 kWh')
        expect(response.body).not_to include(%(datetime="#{morning.started_at.iso8601}"))
      end

      it 'changes each part' do
        evening, morning = charge

        patch "/cars/charging_sessions/#{morning.id}",
              params: { charging_session: { car_id: 'guest', note: 'Visitor' } },
              as: :turbo_stream

        expect(evening.reload).to have_attributes(guest: true, car_id: nil, note: 'Visitor')
        expect(morning.reload).to have_attributes(guest: true, car_id: nil, note: nil)
      end
    end

    it 'offers no delete in the form of a wallbox session' do
      get "/cars/charging_sessions/#{guest.id}/edit"

      expect(response.parsed_body.css('button[formaction]')).to be_empty
    end

    it 'cannot delete a wallbox session' do
      delete "/cars/charging_sessions/#{guest.id}", as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(ChargingSession.exists?(guest.id)).to be(true)
    end
  end

  describe 'the map' do
    let(:year) { Date.current.year }
    let(:map) { response.parsed_body.at_css('[data-controller="car--map--component"]') }

    # The map loads into its frame over the list (see Car::MapOverlay::Component)
    def frame = { 'Turbo-Frame' => Car::MapOverlay::Component::FRAME_ID }

    before { recent.update!(latitude: 50.9, longitude: 14.1) }

    # The address of the tooltip of the only spot, as the map builds it
    def tooltip_path
      id = JSON.parse(map['data-car--map--component-cars-value']).sole['places'].sole[3]
      map['data-car--map--component-tooltip-url-value'].sub(':id', id.to_s)
    end

    it 'shows each offsite session with a position' do
      get '/cars/charging_sessions/offsite/map', headers: frame

      places = JSON.parse(map['data-car--map--component-cars-value']).sole['places']
      expect(places.sole.first(3)).to eq([50.9, 14.1, 1.0])
    end

    it 'links a spot with one session to its form, which leads back to the list' do
      get "/cars/charging_sessions/offsite/#{year}/map", headers: frame

      href = JSON.parse(map['data-car--map--component-cars-value']).sole['places'].sole[4]
      expect(href).to eq("/cars/charging_sessions/#{recent.id}/edit?return_to=#{CGI.escape("/cars/charging_sessions/offsite/#{year}")}")
    end

    it 'loads the tooltip of a spot' do
      get '/cars/charging_sessions/offsite/map', headers: frame
      get tooltip_path

      expect(response.body).to include('Trabant', I18n.l(recent.date))
    end

    it 'puts the street of the address below the town in the tooltip' do
      recent.update_columns(address: 'DE-12345 Town, Main Street 15') # rubocop:disable Rails/SkipsModelValidations
      get '/cars/charging_sessions/offsite/map', headers: frame
      get tooltip_path

      lines = response.parsed_body.at_css('.font-semibold').parent.css('> div').map(&:text)
      expect(lines.first(2)).to eq(['DE-12345 Town', 'Main Street 15'])
    end

    it 'loads the tooltip with the car filter and the timeframe of the list' do
      get "/cars/1/charging_sessions/offsite/#{year}/map", headers: frame
      path = tooltip_path

      expect(path).to start_with('/cars/1/charging_sessions/spots/')
      expect(path).to end_with("/tooltip/#{year}")
    end

    it 'answers a spot without a session with 404' do
      get '/cars/charging_sessions/spots/1/tooltip/all'

      expect(response).to have_http_status(:not_found)
    end

    it 'counts the sessions without a position' do
      get '/cars/charging_sessions/offsite/map', headers: frame

      expect(response.body).to include('1 session without a location is missing from the map')
    end

    it 'lies over the list with its title' do
      get "/cars/charging_sessions/offsite/#{year}/map", headers: frame

      expect(response.body).to include('<turbo-frame id="car_map"', 'car--map-overlay--component', ">#{I18n.t('car_breakdown.offsite_map')}</h2>")
    end

    it 'leads to the list without its frame' do
      get "/cars/charging_sessions/offsite/#{year}/map"

      expect(response).to redirect_to(page('offsite', timeframe: year.to_s))
    end

    it 'shows no map without a session' do
      get '/cars/charging_sessions/offsite/2010/map', headers: frame

      expect(map).to be_nil
    end

    it 'refreshes the list after a save in the form that it opened' do
      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 }, return_to: '/cars/charging_sessions/offsite/map' },
            headers: { 'Turbo-Frame' => 'modal' },
            as: :turbo_stream

      expect(response.body).to include('<turbo-stream action="update" target="list">')
      expect(response.body).not_to include('data-controller="car--map--component"')
    end
  end

  describe 'POST /cars/charging_sessions' do
    it 'creates an offsite session of the user' do
      post '/cars/charging_sessions',
           params: {
             charging_session: { kind: 'wallbox', car_id: car.id, started_at: 1.day.ago, kwh: 12, cost: 6 },
           },
           as: :turbo_stream

      expect(ChargingSession.order(:created_at).last).to have_attributes(kind: 'offsite', origin: 'user', car_id: car.id, kwh: 12)
    end

    it 'names an end before the start in the form' do
      expect do
        post '/cars/charging_sessions',
             params: { charging_session: { car_id: car.id, started_at: 1.day.ago, ended_at: 2.days.ago, kwh: 12, cost: 6 } },
             as: :turbo_stream
      end.not_to change(ChargingSession, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('must be after the start')
    end
  end

  describe 'GET /cars/charging_sessions/:id/edit' do
    it 'opens from a list with its address' do
      get page('offsite', timeframe: Date.current.year.to_s)

      link = response.parsed_body.at_css("a[href^='/cars/charging_sessions/#{recent.id}/edit?']")
      expect(Rack::Utils.parse_query(URI(link['href']).query)).to eq('return_to' => page('offsite', timeframe: Date.current.year.to_s))
    end

    it 'leads back to the list as its address shows it' do
      get "/cars/charging_sessions/#{recent.id}/edit", params: { return_to: '/cars/charging_sessions/offsite' }

      expect(response.parsed_body.at_css('a.ui-title-bar-back')['href']).to eq('/cars/charging_sessions/offsite')
    end

    it 'offers to delete an offsite session in the form' do
      get "/cars/charging_sessions/#{recent.id}/edit"

      buttons = response.parsed_body.css("button[formaction='/cars/charging_sessions/#{recent.id}']")
      expect(buttons.pluck('formmethod')).to eq(%w[delete delete])
    end

    it 'keeps the address of the list in the form, with its timeframe and its car' do
      list = "/cars/#{car.id}/charging_sessions/offsite/#{Date.current.year}"
      get "/cars/charging_sessions/#{recent.id}/edit", params: { return_to: list }

      expect(response.parsed_body.at_css('input[name=return_to]')['value']).to eq(list)
    end
  end

  describe 'PATCH /cars/charging_sessions/:id' do
    # The modal of the desktop submits within its frame
    def update_recent(return_to: page('offsite'))
      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 }, return_to: }.compact,
            headers: { 'Turbo-Frame' => 'modal' },
            as: :turbo_stream
    end

    it 'responds with the updated list' do
      update_recent

      expect(response.body).to include('<turbo-stream action="update" target="list">')
      expect(response.body).to include('7.50')
      expect(response.body).to include(old.started_at.iso8601)
    end

    it 'renders the list of the timeframe of the form' do
      update_recent(return_to: page('offsite', timeframe: Date.current.year.to_s))

      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end

    it 'leads the page of a phone back to the list of the form' do
      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 }, return_to: "/cars/#{car.id}/charging_sessions/offsite/#{Date.current.year}" }

      expect(response).to redirect_to("/cars/#{car.id}/charging_sessions/offsite/#{Date.current.year}")
      expect(recent.reload.cost).to eq(7.5)
    end

    it 'loads the next page of the list from its path, without the query of its address' do
      25.times { ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 3.days.ago + it.minutes, kwh: 1, cost: 1) }
      update_recent(return_to: "#{page('offsite')}?ref=x")

      expect(response.body).to include('src="/cars/charging_sessions/offsite/all?page=')
    end

    it 'leads the page of a phone back to the address of the list that opened the form' do
      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 }, return_to: '/cars/charging_sessions/offsite' },
            as: :turbo_stream

      expect(response.body).to include('<turbo-stream action="back_to" target="/cars/charging_sessions/offsite">')
    end
  end

  # A phone shows the list and its forms in a sheet over the car page (see
  # SheetPage)
  describe 'in the sheet of a phone' do
    def sheet_page = response.parsed_body.at_css('turbo-frame#sheet-page')

    it 'opens the list in the modal frame, not the timeframe select' do
      get page('offsite', timeframe: Date.current.year.to_s), params: { sheet: 1 }, headers: { 'Turbo-Frame' => 'modal' }

      expect(response.parsed_body.at_css('turbo-frame#modal dialog.bottom-sheet')).to be_present
      expect(sheet_page.at_css('h2').text.squish).to eq('Charging sessions')
      expect(sheet_page.at_css('turbo-frame#list')['target']).to eq('sheet-page')
      expect(response.body).not_to include('Select timeframe')
    end

    # The map stands in the head of the sheet, not beside the sums
    it 'has the map in its head, before the button for a new session' do
      get page('offsite'), params: { sheet: 1 }, headers: { 'Turbo-Frame' => 'modal' }

      expect(sheet_page.css('header a').pluck('aria-label')).to eq(['Map of the offsite sessions', I18n.t('charging_sessions.new')])
      expect(sheet_page.css('a[href$="/map"]').size).to eq(1)
    end

    it 'shows the form as a page of the sheet' do
      get "/cars/charging_sessions/#{recent.id}/edit", params: { return_to: page('offsite') }, headers: { 'Turbo-Frame' => 'sheet-page' }

      form = sheet_page.at_css('form.ui-form')
      expect(form['data-turbo-frame']).to eq('sheet-page')
      expect(sheet_page.at_css("button[form='#{form['id']}'][data-form-dirty-submit]")).to be_present
      expect(URI(sheet_page.at_css('header a')['href']).path).to eq(page('offsite'))
    end

    it 'leads back to the list in the sheet after a save' do
      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 }, return_to: page('offsite') },
            headers: { 'Turbo-Frame' => 'sheet-page' },
            as: :turbo_stream

      expect(response).to redirect_to(page('offsite'))
      expect(recent.reload.cost).to eq(7.5)
    end
  end

  describe 'DELETE /cars/charging_sessions/:id' do
    it 'responds with the list without the deleted session' do
      delete "/cars/charging_sessions/#{old.id}", params: { return_to: page('offsite') }, headers: { 'Turbo-Frame' => 'modal' }, as: :turbo_stream

      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end
  end

  describe 'the proposals' do
    let(:started_at) { 1.day.ago.change(hour: 10) }
    let!(:proposal) do
      ChargingSession.insert!( # rubocop:disable Rails/SkipsModelValidations
        { kind: 'offsite', origin: 'detection', car_id: car.id, started_at:, ended_at: started_at + 1.hour, soc_from: 30, soc_to: 70, kwh: 20, latitude: 50.0, longitude: 8.0 },
      )
      ChargingSession.proposals.sole
    end

    # The map and the sums show the sessions that count, so a day with a
    # proposal alone has neither
    it 'offers no map and no sums for a proposal alone' do
      get page('offsite', timeframe: started_at.to_date.iso8601)

      expect(response.body).to include(proposal.started_at.iso8601)
      expect(response.body).not_to include('/map"', '0 charging sessions')
    end

    it 'shows a proposal with its estimate, but leaves it out of the sums' do
      get page('offsite')

      expect(response.body).to include(proposal.started_at.iso8601)
      expect(response.parsed_body.at_css("[role=img][title='#{I18n.t('charging_sessions.proposal.name')}']")).to be_present
      expect(totals).to eq('2 charging sessions · 30.0 kWh · € 15.00')
      expect(review_switch).to have_attributes(text: include('1 unconfirmed'))
    end

    # A kind names its sessions to review with a dot in the switch, also seen
    # from the other kind
    it 'marks the kind with proposals in the switch' do
      allow(Summary).to receive(:missing_or_stale_days_for).and_return([])
      get page('wallbox')

      expect(response.parsed_body.css('nav a .sr-only').map(&:text)).to eq([', 1 unconfirmed'])
    end

    it 'lists the proposals alone, which it dismisses at once' do
      get page('offsite', review: '1')

      expect(response.body).to include(proposal.started_at.iso8601, 'These sessions come from the state of charge of a car', I18n.t('charging_sessions.proposal.dismiss_all'))
      expect(response.body).not_to include(recent.started_at.iso8601)
    end

    it 'shows the proposals only to the admin' do
      logout
      get page('offsite')

      expect(response.body).not_to include(proposal.started_at.iso8601, 'unconfirmed')
    end

    it 'dismisses a proposal' do
      patch "/cars/charging_sessions/#{proposal.id}/dismiss", params: { return_to: page('offsite') }, headers: { 'Turbo-Frame' => 'modal' }, as: :turbo_stream

      expect(proposal.reload).to have_attributes(dismissed: true, assigned_manually: true)
      expect(response.body).not_to include(proposal.started_at.iso8601)
      expect(response.body).to include('Dismissed')
    end

    it 'shows the proposals only in the list of the offsite sessions' do
      get page('wallbox')

      expect(response.body).not_to include(proposal.started_at.iso8601)
    end

    describe 'dismiss all' do
      def list = page('offsite', timeframe: started_at.year.to_s)

      # The list of the proposals alone offers to dismiss them
      def review_list = page('offsite', timeframe: started_at.year.to_s, review: '1')

      def dismiss_all(return_to: list, listed_at: Time.current.iso8601(6), **)
        patch '/cars/charging_sessions/dismiss', params: { return_to:, listed_at: }.compact, **
      end

      def proposal_at(started_at, **)
        ChargingSession.insert!( # rubocop:disable Rails/SkipsModelValidations
          { kind: 'offsite', origin: 'detection', car_id: car.id, started_at:, kwh: 5, ** },
        ).first['id']
      end

      it 'is offered in the list of the proposals, with the time of the list' do
        freeze_time do
          get review_list

          form = response.parsed_body.at_css('form[action="/cars/charging_sessions/dismiss"]')
          expect(form['data-turbo-confirm']).to eq('Dismiss 1 unconfirmed charging session? It stays saved, but no longer shows and is not proposed again.')
          expect(form.at_css('input[name="return_to"]')['value']).to eq(review_list)
          expect(form.at_css('input[name="listed_at"]')['value']).to eq(Time.current.iso8601(6))
        end
      end

      it 'is not offered without a proposal, nor in the list of all sessions' do
        get list
        expect(response.parsed_body.at_css('form[action="/cars/charging_sessions/dismiss"]')).to be_nil

        proposal.dismiss!
        get review_list

        expect(response.parsed_body.at_css('form[action="/cars/charging_sessions/dismiss"]')).to be_nil
      end

      it 'dismisses the proposals of the timeframe of the list, but no session of the user' do
        proposal_at(started_at - 2.years)

        dismiss_all(headers: { 'Turbo-Frame' => 'list' }, as: :turbo_stream)

        expect(proposal.reload).to have_attributes(dismissed: true, assigned_manually: true)
        expect(ChargingSession.proposals.count).to eq(1)
        expect(recent.reload.dismissed).to be(false)
        expect(response.body).to include('1 charging session dismissed', recent.started_at.iso8601)
        expect(response.body).not_to include(proposal.started_at.iso8601)
      end

      it 'dismisses the proposals of the whole time in the list of all' do
        dismiss_all(return_to: page('offsite'))

        expect(response).to redirect_to(page('offsite'))
        expect(ChargingSession.proposals).to be_empty
      end

      it 'keeps a proposal of a build after the list' do
        listed_at = Time.current
        later = proposal_at(started_at + 1.hour, created_at: listed_at + 1.second, updated_at: listed_at + 1.second)

        dismiss_all(listed_at: listed_at.iso8601(6))

        expect(proposal.reload.dismissed).to be(true)
        expect(ChargingSession.proposals.ids).to eq([later])
      end

      it 'refuses a request without its list or the time of the list' do
        dismiss_all(return_to: nil)
        expect(response).to have_http_status(:unprocessable_content)

        dismiss_all(listed_at: 'yesterday')
        expect(response).to have_http_status(:unprocessable_content)
        expect(proposal.reload).to be_proposal
      end
    end

    it 'dismisses no session of the user' do
      patch "/cars/charging_sessions/#{recent.id}/dismiss", as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(recent.reload.dismissed).to be(false)
    end

    # The form asks Nominatim once it opened (see the spec of the address check)
    describe 'the form that needs Nominatim' do
      def lookup_pending = response.parsed_body.at_css('[data-controller="address-lookup"]')['data-address-lookup-pending-value']

      it 'opens without Nominatim for a position without an address' do
        recent.update_columns(latitude: 50.0, longitude: 8.0) # rubocop:disable Rails/SkipsModelValidations
        allow(Place).to receive(:address_at)

        get "/cars/charging_sessions/#{recent.id}/edit"

        expect(lookup_pending).to eq('true')
        expect(response.parsed_body.at_css('input[name="charging_session[address]"]')['value']).to be_nil
        expect(Place).not_to have_received(:address_at)
      end

      it 'opens without Nominatim for an address from before without a position' do
        recent.update_columns(address: 'Main Street 1, 12345 Town') # rubocop:disable Rails/SkipsModelValidations
        allow(Place).to receive(:search)

        get "/cars/charging_sessions/#{recent.id}/edit"

        expect(lookup_pending).to eq('true')
        expect(Place).not_to have_received(:search)
      end

      it 'is not pending for an address with a position' do
        recent.update_columns(address: 'DE-12345 Town, Main Street 1', latitude: 51.0, longitude: 7.0) # rubocop:disable Rails/SkipsModelValidations

        get "/cars/charging_sessions/#{recent.id}/edit"

        expect(lookup_pending).to be_nil
      end
    end

    it 'keeps the point that the user moved on the map, without Nominatim' do
      recent.update_columns(address: 'DE-12345 Town, Main Street 1', latitude: 51.0, longitude: 7.0) # rubocop:disable Rails/SkipsModelValidations
      allow(Place).to receive(:search)

      get "/cars/charging_sessions/#{recent.id}/edit"
      map = response.parsed_body.at_css('#charging_session_map')
      expect(map['data-action']).to eq('car--map--component:moved->address-lookup#move')
      expect(map.at_css('[data-car--map--component-movable-value]')).to be_present

      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { address: 'DE-12345 Town, Main Street 1', address_of_position: 'DE-12345 Town, Main Street 1', latitude: '51.0005', longitude: '7.0004' } },
            as: :turbo_stream

      expect(recent.reload).to have_attributes(latitude: 51.0005, longitude: 7.0004)
      expect(Place).not_to have_received(:search)
    end

    it 'shows a point that does not move without an address' do
      recent.update_columns(latitude: 51.0, longitude: 7.0) # rubocop:disable Rails/SkipsModelValidations

      get "/cars/charging_sessions/#{recent.id}/edit"

      map = response.parsed_body.at_css('#charging_session_map [data-controller="car--map--component"]')
      expect(map['data-car--map--component-live-value']).to eq('true')
      expect(map['data-car--map--component-movable-value']).to be_nil
    end

    it 'shows a point that does not move without Nominatim' do
      recent.update_columns(address: 'DE-12345 Town, Main Street 1', latitude: 51.0, longitude: 7.0) # rubocop:disable Rails/SkipsModelValidations
      allow(Rails.configuration.x).to receive(:nominatim_url).and_return(nil)

      get "/cars/charging_sessions/#{recent.id}/edit"

      map = response.parsed_body.at_css('#charging_session_map [data-controller="car--map--component"]')
      expect(map['data-car--map--component-movable-value']).to be_nil
    end

    it 'shows no map without a position' do
      get "/cars/charging_sessions/#{recent.id}/edit"

      expect(response.parsed_body.at_css('[data-controller="car--map--component"]')).to be_nil
    end

    it 'refuses to save an address that Nominatim does not find' do
      allow(Place).to receive(:search).and_return(nil)

      patch "/cars/charging_sessions/#{recent.id}", params: { charging_session: { address: 'Nowhere' } }, as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('was not found')
      expect(recent.reload.address).to be_nil
    end

    it 'offers to dismiss a proposal beside its hint, not as a button of the form' do
      get "/cars/charging_sessions/#{proposal.id}/edit", params: { return_to: page('offsite') }

      body = response.parsed_body
      form = body.at_css("form[action='/cars/charging_sessions/#{proposal.id}/dismiss']")
      expect(form.at_css('input[name="_method"]')['value']).to eq('patch')
      expect(form.at_css('input[name="return_to"]')['value']).to eq(page('offsite'))
      expect(body.at_css("button[form='#{form['id']}']").text).to include('Dismiss')
      expect(body.css('button[formaction]')).to be_empty
    end

    it 'accepts a proposal with its cost' do
      patch "/cars/charging_sessions/#{proposal.id}", params: { charging_session: { cost: 9 } }, as: :turbo_stream

      expect(proposal.reload).to have_attributes(assigned_manually: true, cost: 9)
    end
  end
end
