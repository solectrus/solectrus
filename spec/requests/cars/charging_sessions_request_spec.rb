describe 'Charging sessions' do
  before { login_as_admin }

  let(:car) { Car.create!(id: 1, name: 'Trabant') }
  let!(:recent) do
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 2.days.ago, kwh: 10, cost: 5)
  end
  let!(:old) do
    ChargingSession.create!(kind: :offsite, origin: :user, car:, started_at: 2.years.ago, kwh: 20, cost: 10)
  end

  def wallbox(started_at, **)
    ChargingSession.create!(kind: :wallbox, origin: :detection, started_at:, ended_at: started_at + 1.hour, kwh: 7, **)
  end

  describe 'GET /cars/charging_sessions' do
    it 'redirects to the default kind' do
      get '/cars/charging_sessions'
      expect(response).to redirect_to('/cars/charging_sessions/wallbox')
    end
  end

  describe 'GET /cars/charging_sessions/:kind' do
    it 'defaults to timeframe "all" and lists all sessions for that kind' do
      get '/cars/charging_sessions/offsite'
      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).to include(old.started_at.iso8601)
    end

    it 'shows the car of each session' do
      get '/cars/charging_sessions/offsite'
      expect(response.body).to include('Trabant')
    end

    it 'goes back to the car page in the timeframe and with the car' do
      get '/cars/1/charging_sessions/offsite/2025'
      expect(response.body).to include(%(href="/cars/1/car_charging/2025"))
    end

    it 'offers a new offsite session' do
      get '/cars/charging_sessions/offsite'
      expect(response.body).to include('/cars/charging_sessions/new')
    end

    it 'offers no new wallbox session, the detection writes them' do
      get '/cars/charging_sessions/wallbox/now'
      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('/cars/charging_sessions/new')
    end

    # An offsite session needs a car
    context 'without a car' do
      before { Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_CAR_BATTERY_SOC')) }

      it 'offers no new offsite session' do
        get '/cars/charging_sessions/offsite'
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('/cars/charging_sessions/new')
      end
    end

    context 'without a wallbox' do
      before { Sensor::Config.setup(ENV.to_h.except('INFLUX_SENSOR_WALLBOX_POWER', 'INFLUX_SENSOR_WALLBOX_CAR_CONNECTED')) }

      it 'offers no tab of the wallbox sessions' do
        get '/cars/charging_sessions/offsite'
        expect(response.body).not_to include('/cars/charging_sessions/wallbox')
      end

      # The sessions of an earlier wallbox stay as history
      it 'keeps the tab while wallbox sessions exist' do
        wallbox(3.days.ago)
        get '/cars/charging_sessions/offsite'
        expect(response.body).to include('/cars/charging_sessions/wallbox')
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

  describe 'GET /cars/charging_sessions/:kind/:timeframe' do
    it 'filters sessions to the given timeframe' do
      get "/cars/charging_sessions/offsite/#{Date.current.year}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end

    it 'renders an empty state message when no sessions match the filter' do
      get '/cars/charging_sessions/offsite/day'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No offsite charging sessions')
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
      get "/cars/charging_sessions/offsite/#{year}"

      expect(response.body).to include("/cars/3/charging_sessions/offsite/#{year}")
      expect(response.body).not_to include("/cars/2/charging_sessions/offsite/#{year}")
    end

    it 'offers a sold car in a timeframe of its period' do
      get "/cars/charging_sessions/offsite/#{year - 1}"

      expect(response.body).to include("/cars/2/charging_sessions/offsite/#{year - 1}")
    end

    it 'redirects a car outside the timeframe to "all"' do
      get "/cars/2/charging_sessions/offsite/#{year}"

      expect(response).to redirect_to("/cars/charging_sessions/offsite/#{year}")
    end

    # The add button of the list carries its timeframe and its car
    describe 'in the form of a new session' do
      def new_session(**params)
        get '/cars/charging_sessions/new', params:, headers: { 'Turbo-Frame' => 'modal' }
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
    end
  end

  describe 'the timeframe' do
    it 'goes to the list of the kind before and after' do
      get '/cars/charging_sessions/offsite/2025'

      expect(response.body).to include('href="/cars/charging_sessions/offsite/2024"')
      expect(response.body).to include('href="/cars/charging_sessions/offsite/2026"')
    end

    it 'opens its select from its own address' do
      get '/cars/charging_sessions/offsite/2025'

      expect(response.parsed_body.at_css('a[href="/cars/charging_sessions/offsite/2025"][data-turbo-frame="modal"]')).to be_present
    end
  end

  describe 'GET /cars/charging_sessions/:kind/:timeframe in the modal' do
    let(:path) { '/cars/1/charging_sessions/offsite/2025' }

    it 'selects a timeframe of the list of the kind and keeps the car' do
      get path, headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('data-timeframe-select--component-base-url-value="/cars/1/charging_sessions/offsite"')
      expect(response.body).not_to include(recent.started_at.iso8601)
    end

    it 'offers the hours, unlike the car page' do
      get path, headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('data-value="P24H"')
    end
  end

  describe 'the wallbox sessions' do
    def day = 3.days.ago.to_date

    let!(:unassigned) { wallbox(day.in_time_zone.change(hour: 9)) }
    let!(:guest) { wallbox(day.in_time_zone.change(hour: 14), guest: true) }

    before do
      (Date.current.beginning_of_year..Date.current).each do |date|
        Summary.create!(date:, steps: Summary::Steps.versions)
      end
    end

    it 'shows "all" with the guest and the open sessions, and counts them' do
      get "/cars/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include(unassigned.started_at.iso8601, guest.started_at.iso8601, '2 <span class="font-light">charging sessions</span>')
    end

    it 'shows the PV share of each session and of all' do
      allow(Sensor::Config).to receive(:exists?).and_call_original
      allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(true)
      unassigned.update!(kwh_grid: 1.75)
      guest.update!(kwh_grid: 7)

      get "/cars/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include('75% from PV', '0% from PV', '38% from PV')
    end

    it 'shows no PV share without the power splitter' do
      allow(Sensor::Config).to receive(:exists?).and_call_original
      allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(false)

      get "/cars/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).not_to include('from PV')
    end

    it 'filters the sessions that are not assigned' do
      get "/cars/unassigned/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include(unassigned.started_at.iso8601)
      expect(response.body).not_to include(guest.started_at.iso8601)
    end

    it 'goes back to the car page without the guest filter, which it does not select' do
      get "/cars/guest/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include(%(href="/cars/car_charging/#{Date.current.year}"))
    end

    it 'drops the guest filter in the tab of the offsite sessions' do
      get "/cars/guest/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include(%(href="/cars/charging_sessions/offsite/#{Date.current.year}"))
    end

    it 'builds the detection of a pending day first' do
      Summary.find(day).update!(steps: {})

      get "/cars/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include("d_#{day}_#{day}", 'steps=charging_sessions')
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

      # A single charge has no sums, the row says it all
      it 'shows one charge and counts it once' do
        evening, morning = charge
        Summary.find_or_create_by!(date: day - 1) { it.steps = Summary::Steps.versions }

        get "/cars/#{car.id}/charging_sessions/wallbox/#{day - 1}..#{day}"

        expect(response.body).to include(evening.started_at.iso8601)
        expect(response.body).not_to include('<span class="font-light">charging session')
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

    it 'cannot delete a wallbox session' do
      delete "/cars/charging_sessions/#{guest.id}", as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(ChargingSession.exists?(guest.id)).to be(true)
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
  end

  describe 'GET /cars/charging_sessions/:id/edit' do
    it 'opens from a list with its timeframe' do
      get "/cars/charging_sessions/offsite/#{Date.current.year}"

      button = response.parsed_body.at_css("form[action='/cars/charging_sessions/#{recent.id}/edit']")
      expect(button.at_css('input[name=timeframe]')['value']).to eq(Date.current.year.to_s)
    end

    it 'carries the timeframe and the car filter of the list into the form' do
      get "/cars/charging_sessions/#{recent.id}/edit", params: { timeframe: Date.current.year.to_s, car: car.id }

      form = response.parsed_body
      expect(form.at_css('input[name=timeframe]')['value']).to eq(Date.current.year.to_s)
      expect(form.at_css('input[name=car]')['value']).to eq(car.id.to_s)
    end
  end

  describe 'PATCH /cars/charging_sessions/:id' do
    def update_recent(**list_params)
      patch "/cars/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 }, **list_params },
            as: :turbo_stream
    end

    it 'responds with the updated list' do
      update_recent

      expect(response.body).to include('<turbo-stream action="update" target="list">')
      expect(response.body).to include('7.50')
      expect(response.body).to include(old.started_at.iso8601)
    end

    it 'renders the list of the timeframe of the form' do
      update_recent(timeframe: Date.current.year.to_s)

      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end
  end

  describe 'DELETE /cars/charging_sessions/:id' do
    it 'responds with the list without the deleted session' do
      delete "/cars/charging_sessions/#{old.id}", as: :turbo_stream

      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end
  end
end
