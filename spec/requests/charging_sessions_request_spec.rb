describe 'Charging sessions' do
  before { login_as_admin }

  let(:car) { Car.create!(id: 1, name: 'Trabant') }
  let!(:recent) do
    ChargingSession.create!(kind: :offsite, car:, started_at: 2.days.ago, kwh: 10, cost: 5)
  end
  let!(:old) do
    ChargingSession.create!(kind: :offsite, car:, started_at: 2.years.ago, kwh: 20, cost: 10)
  end

  def wallbox(started_at, **)
    ChargingSession.create!(kind: :wallbox, started_at:, ended_at: started_at + 1.hour, kwh: 7, **)
  end

  describe 'GET /charging_sessions' do
    it 'redirects to the first kind' do
      get '/charging_sessions'
      expect(response).to redirect_to('/charging_sessions/wallbox')
    end
  end

  describe 'GET /charging_sessions/:kind' do
    it 'defaults to timeframe "all" and lists all sessions for that kind' do
      get '/charging_sessions/offsite'
      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).to include(old.started_at.iso8601)
    end

    it 'shows the car of each session' do
      get '/charging_sessions/offsite'
      expect(response.body).to include('Trabant')
    end
  end

  describe 'GET /charging_sessions/:kind/:timeframe' do
    it 'filters sessions to the given timeframe' do
      get "/charging_sessions/offsite/#{Date.current.year}"
      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end

    it 'renders an empty state message when no sessions match the filter' do
      get '/charging_sessions/offsite/day'
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No offsite charging sessions for')
    end

    it 'renders the generic empty state message for timeframe "all"' do
      ChargingSession.delete_all
      get '/charging_sessions/offsite/all'
      expect(response.body).to include('No offsite charging sessions recorded')
    end
  end

  describe 'the timeframe' do
    it 'goes to the list of the kind before and after' do
      get '/charging_sessions/offsite/2025'

      expect(response.body).to include('href="/charging_sessions/offsite/2024"')
      expect(response.body).to include('href="/charging_sessions/offsite/2026"')
    end

    it 'opens its own select' do
      get '/charging_sessions/offsite/2025'

      expect(response.body).to include('href="/charging_sessions/timeframe-select/offsite/2025"')
    end
  end

  describe 'GET /charging_sessions/timeframe-select/:kind/:timeframe' do
    let(:path) { '/charging_sessions/timeframe-select/offsite/2025?car=1' }

    it 'selects a timeframe of the list of the kind and keeps the car' do
      get path, headers: { 'Turbo-Frame' => 'modal' }

      expect(response.body).to include('data-timeframe-select--component-base-url-value="/charging_sessions/offsite"')
      expect(response.body).to include('data-timeframe-select--component-query-value="?car=1"')
    end

    it 'sends a request without a frame to the list' do
      get path

      expect(response).to redirect_to('/charging_sessions/offsite/2025?car=1')
    end
  end

  describe 'the wallbox sessions' do
    def day = 3.days.ago.to_date

    let!(:not_assigned) { wallbox(day.in_time_zone.change(hour: 9)) }
    let!(:guest) { wallbox(day.in_time_zone.change(hour: 14), guest: true) }

    before do
      (Date.current.beginning_of_year..Date.current).each do |date|
        Summary.create!(date:, charging_sessions_version: ChargingSession::Detection::VERSION)
      end
    end

    it 'shows "all" with the guest and the open sessions, and counts them' do
      get "/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include(not_assigned.started_at.iso8601, guest.started_at.iso8601, '2 <small class="font-light">charging sessions</small>')
    end

    it 'shows the PV share of each session and of all' do
      allow(Sensor::Config).to receive(:exists?).and_call_original
      allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(true)
      not_assigned.update!(kwh_grid: 1.75)
      guest.update!(kwh_grid: 7)

      get "/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include('75% from PV', '0% from PV', '38% from PV')
    end

    it 'shows no PV share without the power splitter' do
      allow(Sensor::Config).to receive(:exists?).and_call_original
      allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(false)

      get "/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).not_to include('from PV')
    end

    it 'filters the sessions that are not assigned' do
      get "/charging_sessions/wallbox/#{Date.current.year}?car=not_assigned"

      expect(response.body).to include(not_assigned.started_at.iso8601)
      expect(response.body).not_to include(guest.started_at.iso8601)
    end

    it 'drops the guest filter in the tab of the offsite sessions' do
      get "/charging_sessions/wallbox/#{Date.current.year}?car=guest"

      expect(response.body).to include(%(href="/charging_sessions/offsite/#{Date.current.year}"))
    end

    it 'builds the detection of a pending day first' do
      Summary.find(day).update!(charging_sessions_version: nil)

      get "/charging_sessions/wallbox/#{Date.current.year}"

      expect(response.body).to include("d_#{day}_#{day}", 'charging_sessions=1')
    end

    it 'assigns a session to a car' do
      get '/charging_sessions/wallbox'
      patch "/charging_sessions/#{not_assigned.id}",
            params: { charging_session: { car_id: car.id, note: 'Trip' } },
            as: :turbo_stream

      expect(not_assigned.reload).to have_attributes(car_id: car.id, guest: false, note: 'Trip')
    end

    it 'marks a session as a guest charge and keeps its energy' do
      patch "/charging_sessions/#{not_assigned.id}",
            params: { charging_session: { car_id: 'guest', kwh: 99 } },
            as: :turbo_stream

      expect(not_assigned.reload).to have_attributes(car_id: nil, guest: true, kwh: 7)
    end

    it 'cannot delete a wallbox session' do
      delete "/charging_sessions/#{guest.id}", as: :turbo_stream

      expect(response).to have_http_status(:unprocessable_content)
      expect(ChargingSession.exists?(guest.id)).to be(true)
    end
  end

  describe 'POST /charging_sessions' do
    it 'creates an offsite session' do
      post '/charging_sessions',
           params: {
             charging_session: { kind: 'wallbox', car_id: car.id, started_at: 1.day.ago, kwh: 12, cost: 6 },
           },
           as: :turbo_stream

      expect(ChargingSession.order(:created_at).last).to have_attributes(kind: 'offsite', car_id: car.id, kwh: 12)
    end
  end

  describe 'PATCH /charging_sessions/:id' do
    def update_recent
      patch "/charging_sessions/#{recent.id}",
            params: { charging_session: { cost: 7.5 } },
            as: :turbo_stream
    end

    it 'responds with the updated list' do
      get '/charging_sessions/offsite'
      update_recent

      expect(response.body).to include('<turbo-stream action="update" target="list">')
      expect(response.body).to include('7.50')
      expect(response.body).to include(old.started_at.iso8601)
    end

    it 'keeps the timeframe of the last index render' do
      get "/charging_sessions/offsite/#{Date.current.year}"
      update_recent

      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end
  end

  describe 'DELETE /charging_sessions/:id' do
    it 'responds with the list without the deleted session' do
      get '/charging_sessions/offsite'
      delete "/charging_sessions/#{old.id}", as: :turbo_stream

      expect(response.body).to include(recent.started_at.iso8601)
      expect(response.body).not_to include(old.started_at.iso8601)
    end
  end
end
