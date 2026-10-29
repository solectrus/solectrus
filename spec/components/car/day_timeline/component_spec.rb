describe Car::DayTimeline::Component, type: :component do
  subject(:html) { render_inline(described_class.new(timeline:)) }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  # A time from one clock to another, as the tooltip writes it
  def range(from, to) = "#{from}\u202F–\u202F#{to}"

  def car = Car.new(id: 1, name: 'Trabant')

  def soc = [[at(0), 80], [at(9), 40], [at(18), 90]]

  # The line of the readings, its fall on the drive and its rise on the charge
  def soc_line = Car::DayTimeline::SocLine.new(soc, ends_at: at(18), drives: [[drive.started_at || drive.ended_at, drive.ended_at]], charges: [[at(12), at(18)]]).call

  let(:drive) { Car::DayTimeline::Drives::Drive.new(started_at: at(6), ended_at: at(9), distance: 120) }
  let(:session) { ChargingSession.new(kind: :wallbox, car_id: 1, started_at: at(12), ended_at: at(18), kwh: 20, kwh_grid: 5, cost: 3.5, soc_from: 40, soc_to: 90) }
  let(:visits) { [] }
  let(:lanes) { [Car::DayTimeline::Lane.new(car:, drives: [drive], charges: [charge(session)], soc_line:, visits:)] }
  let(:timeline) { instance_double(Car::DayTimeline, lanes:, timeframe: Timeframe.new('2026-06-15'), now?: false) }

  def charge(session) = Car::DayTimeline::Charge.new(session:, spans: [[session.started_at, session.ended_at]])

  # The left and the right edge of each bar, in percent of the day
  def bars = html.css('[role="img"][data-controller="tooltip"]')

  def edges(bar) = bar['style'].scan(/[\d.]+%/).map(&:to_f)

  before do
    Sensor::Config.setup(ENV.to_h.merge('INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer'))
  end

  after { Sensor::Config.setup(ENV) }

  it 'places the drive and the charge on the day' do
    drive_bar, charge_bar = bars

    # right: 100 - 37.5, width: 12.5 of the day
    expect(edges(drive_bar)).to eq([62.5, 12.5])
    expect(edges(charge_bar)).to eq([25.0, 25.0])
  end

  # Side by side, the parts would read as one after the other in time
  it 'stacks the sources of the charge, PV at the bottom' do
    parts = bars.last.css('> span')

    expect(bars.last['class']).to include('flex-col-reverse')
    expect(parts.pluck('style')).to eq(['flex-grow: 75.0; background: var(--color-car-pv)', 'flex-grow: 25.0; background: var(--color-car-grid)'])
  end

  context 'with a charge of less than 1 kWh' do
    let(:session) { ChargingSession.new(kind: :wallbox, car_id: 1, started_at: at(12), ended_at: at(12, 10), kwh: 0.4, kwh_grid: 0.3) }

    # A flex-grow sum below 1 would fill only that part of the height
    it 'fills the whole height with the sources' do
      parts = bars.last.css('> span')

      expect(parts.pluck('style')).to eq(['flex-grow: 25.0; background: var(--color-car-pv)', 'flex-grow: 75.0; background: var(--color-car-grid)'])
    end
  end

  # The power splitter split the first hour, but not the second one yet
  context 'with the curve of the wallbox' do
    let(:lanes) do
      point = Car::DayTimeline::ChargePower::Point
      power = [point.new(time: at(12), pv: 3000.0, grid: 1000.0, unsplit: 0.0), point.new(time: at(15), pv: 0.0, grid: 0.0, unsplit: 2000.0), point.new(time: at(18), pv: 0.0, grid: 0.0, unsplit: 2000.0)]
      charge = Car::DayTimeline::Charge.new(session:, spans: [[at(12), at(18)]], power:)
      [Car::DayTimeline::Lane.new(car:, drives: [], charges: [charge], soc_line: [], visits: [])]
    end

    it 'draws the power over the time of the charge, PV at the bottom' do
      areas = bars.last.css('svg path')

      expect(bars.last['class']).to include('bg-fill')
      expect(bars.last.css('> span')).to be_empty
      expect(areas.pluck('style')).to eq(['fill: var(--color-car-pv)', 'fill: var(--color-car-grid)', 'fill: var(--color-car-wallbox)'])
      # The highest power of the day fills the height
      expect(areas.first['d']).to eq('M0.0 25.0 L500.0 100.0 L1000.0 100.0 L1000.0 100.0 L500.0 100.0 L0.0 100.0 Z')
      expect(areas.last['d']).to eq('M0.0 0.0 L500.0 50.0 L1000.0 50.0 L1000.0 100.0 L500.0 100.0 L0.0 0.0 Z')
    end
  end

  it 'tells the numbers of each bar in its tooltip' do
    drive_bar, charge_bar = bars

    expect(drive_bar['aria-label']).to eq("Driving, #{range('06:00', '09:00')}, Distance 120 km, SOC 80 → 40 %")
    expect(charge_bar['aria-label']).to eq("Charging at the wallbox, #{range('12:00', '18:00')}, Charged 20.0 kWh, SOC 40 → 90 %, Cost 3.50 €, PV share 75 %")
  end

  # The scale runs from 0 to 100 %. The readings lie far apart, so the fall
  # on the drive and the rise on the charge are estimates, drawn dashed.
  it 'draws the state of charge as a line that falls on the drive and rises on the charge' do
    known, estimated = html.css('svg path[fill="none"]').partition { it['stroke-dasharray'].nil? }

    expect(known.sole['d']).to eq('M0.0 20.0 L250.0 20.0 M375.0 60.0 L500.0 60.0')
    expect(estimated.sole['d']).to eq('M250.0 20.0 L375.0 60.0 M500.0 60.0 L750.0 10.0')
  end

  it 'says in the tooltip of an estimate that it is one' do
    notes = html.css('[aria-hidden="true"][data-controller="tooltip"]').map { it.text.include?('Readings with gaps, so the course is estimated') }

    expect(notes).to eq([false, true, false, true])
  end

  it 'has a tooltip on each step of the line' do
    steps = html.css('[aria-hidden="true"][data-controller="tooltip"]').map { [it.at_css('.tooltip-title').text.squish, it.at_css('.tooltip-title + span > span').text] }

    expect(steps).to eq([['SOC 80 %', 'until 06:00'], ['SOC 80 → 40 %', range('06:00', '09:00')], ['SOC 40 %', range('09:00', '12:00')], ['SOC 40 → 90 %', range('12:00', '18:00')]])
  end

  # The last value holds over midnight
  context 'with a line up to the end of the day' do
    def soc_line = Car::DayTimeline::SocLine.new(soc, ends_at: at(0) + 1.day).call

    it 'names no end of the last step of the line' do
      last = html.css('[aria-hidden="true"][data-controller="tooltip"]').last

      expect(last.at_css('.tooltip-title + span > span').text).to eq('since 18:00')
    end
  end

  # The running day ends at 18:00, so the last value still holds
  context 'with the running day' do
    before { allow(timeline).to receive(:now?) { |time| time >= at(18) } }

    def steps = html.css('[aria-hidden="true"][data-controller="tooltip"]')

    it 'names no end of the last step of the line' do
      expect(steps.last.at_css('.tooltip-title + span > span').text).to eq('since 12:00')
    end

    # The value came from before midnight and still holds
    context 'with one value all day' do
      def soc_line = Car::DayTimeline::SocLine.new([[at(0), 79]], ends_at: at(18)).call

      it 'names no time' do
        expect(steps.sole.at_css('.tooltip-title').text.squish).to eq('SOC 79 %')
        expect(steps.sole.text).not_to match(/\d\d:\d\d/)
      end
    end
  end

  # The odometer tells only when the drive ended
  context 'with a drive without a start' do
    let(:drive) { Car::DayTimeline::Drives::Drive.new(started_at: nil, ended_at: at(9), distance: 3) }

    it 'marks its end and says so' do
      expect(edges(bars.first)).to eq([62.5, 0.0])
      expect(bars.first['aria-label']).to start_with('Driving, until 09:00').and include('so the start is unknown')
    end
  end

  # A car that reports each hour: a short drive at some time in the hour
  context 'with a drive too slow for its time' do
    let(:drive) { Car::DayTimeline::Drives::Drive.new(started_at: at(8, 15), ended_at: at(9), distance: 1) }

    it 'shows the window with jagged edges and says so' do
      expect(bars.first['class']).to include('timeline-bar-estimated', 'timeline-bar-estimated-start')
      expect(bars.first['aria-label']).to include('the drive took place at some time in this window')
    end
  end

  context 'with a drive too fast for its time' do
    let(:drive) { Car::DayTimeline::Drives::Drive.new(started_at: at(8), ended_at: at(9), distance: 255) }

    it 'marks its start and says so' do
      expect(bars.first['class']).to include('timeline-bar-estimated-start')
      expect(bars.first['aria-label']).to include('The distance does not fit the duration')
    end
  end

  # A gap in the readings before the drive
  context 'with a drive with an estimated start' do
    let(:drive) { Car::DayTimeline::Drives::Drive.new(started_at: nil, earliest_at: at(7), ended_at: at(9), distance: 120) }

    it 'starts at the earliest time with a jagged edge and says so' do
      expect(edges(bars.first)).to eq([62.5, 8.333])
      expect(bars.first['class']).to include('timeline-bar-estimated-start')
      expect(bars.first['aria-label']).to start_with("Driving, #{range('07:00', '09:00')}").and include('Readings with gaps, so the start is estimated')
    end

    context 'when it is too slow for its time' do
      let(:drive) { Car::DayTimeline::Drives::Drive.new(started_at: nil, earliest_at: at(7), ended_at: at(9), distance: 1) }

      it 'names only the window' do
        expect(bars.first['aria-label']).to include('the drive took place at some time in this window')
        expect(bars.first['aria-label']).not_to include('so the start is estimated')
      end
    end
  end

  # Only the admin gets the visits (see Car::DayTimeline)
  context 'with the visits of places' do
    let(:visits) do
      [
        PlaceVisit.new(started_at: at(0), ended_at: at(6), place: Place.new(name: 'Home')),
        PlaceVisit.new(started_at: at(9, 5), ended_at: at(17), place: Place.new(name: 'Office')),
      ]
    end

    it 'names the start and the goal of the drive' do
      expect(bars.first['aria-label']).to include('Home → Office')
    end
  end

  # The place of an offsite session is personal data, like in the list
  context 'with an offsite session' do
    let(:session) { ChargingSession.new(id: 7, kind: :offsite, car_id: 1, started_at: at(12), ended_at: at(13), kwh: 30, address: 'Hauptstraße 1, Bensheim') }

    it 'names its place to the admin alone' do
      allow(vc_test_controller).to receive(:admin?).and_return(true)
      expect(html.css('a[aria-label*="Hauptstraße 1, Bensheim"]')).to be_present

      allow(vc_test_controller).to receive(:admin?).and_return(false)
      expect(render_inline(described_class.new(timeline:)).text).not_to include('Hauptstraße')
    end

    # In the modal on the desktop, in a sheet on a phone
    it 'opens its form for the admin with a click' do
      allow(vc_test_controller).to receive(:admin?).and_return(true)

      desktop, phone = html.css('a[href^="/cars/charging_sessions/7/edit"]').pluck('href')
      expect(desktop).not_to include('sheet=1')
      expect(phone).to include('sheet=1')
      expect(html.css('a[data-turbo-frame="modal"][href^="/cars/charging_sessions/7/edit"]').size).to eq(2)
    end

    it 'opens nothing for a guest' do
      allow(vc_test_controller).to receive(:admin?).and_return(false)

      expect(html.css('a[href*="/edit"]')).to be_empty
    end
  end

  context 'with a day that runs' do
    before { travel_to at(18) }

    # The figures refresh every few minutes, so now names no time
    it 'marks now and leaves the label of the hour beside it to now' do
      expect(html.css('span[style="left: 75.0%"]').map(&:text)).to eq(%w[18:00 now])
    end
  end

  context 'with several cars' do
    let(:lanes) do
      [
        Car::DayTimeline::Lane.new(car:, drives: [drive], charges: [], soc_line: [], visits: []),
        Car::DayTimeline::Lane.new(car: nil, drives: [], charges: [charge(session)], soc_line: [], visits: []),
      ]
    end

    it 'draws a timeline for each car and for the guest, each with its name' do
      expect(html.css('section').size).to eq(2)
      expect(html.css('h2 span').map { it.text.squish }).to eq([car.display_name, 'Guest'])
    end
  end

  it 'names no car on a single timeline' do
    expect(html.css('h2 span')).to be_empty
  end

  # "all" with a single car in use on the day
  context 'when named' do
    subject(:html) { render_inline(described_class.new(timeline:, named: true)) }

    it 'names the car also on a single timeline' do
      expect(html.css('h2 span').map { it.text.squish }).to eq([car.display_name])
    end
  end

  # The wallbox sent no data from 15:00 to 16:30
  context 'with a gap in the data of the wallbox' do
    let(:lanes) do
      charge = Car::DayTimeline::Charge.new(session:, spans: [[at(12), at(18)]], gaps: [[at(15), at(16, 30)]])
      [Car::DayTimeline::Lane.new(car:, drives: [], charges: [charge], soc_line: [], visits: [])]
    end

    it 'dots the gap and says so' do
      expect(bars.last.at_css('.timeline-bar-gap')['style']).to eq('left: 50.0%; width: 25.0%')
      expect(bars.last['aria-label']).to end_with('The wallbox sent no readings for a while')
    end
  end

  # The car stayed plugged in from 14:00 to 16:00 and after the charge
  context 'with a pause and a plug' do
    let(:lanes) do
      charge = Car::DayTimeline::Charge.new(session:, spans: [[at(12), at(14)], [at(16), at(18)]])
      [Car::DayTimeline::Lane.new(car:, drives: [], charges: [charge], soc_line: [], visits: [], plugged: [[at(18), at(20)]])]
    end

    it 'draws the charge as one bar with its pause in grey, and the plug as a grey bar' do
      plug_bar, charge_bar = bars

      expect(edges(charge_bar)).to eq([25.0, 25.0])
      expect(charge_bar.at_css('.bg-car-plugged')['style']).to eq('left: 33.333%; width: 33.333%')
      expect(charge_bar['aria-label']).to include("Charging at the wallbox, #{range('12:00', '18:00')}", 'Charged 20.0 kWh')
      # The end of the charge tells its start
      expect(plug_bar['aria-label']).to eq('Plugged in, until 20:00')
    end

    # On the running day, the car is plugged in up to now
    it 'keeps a time plugged in up to now open' do
      allow(timeline).to receive(:now?).and_return(true)
      plug_bar = bars.first

      expect(plug_bar['aria-label']).to eq('Plugged in')
      expect(plug_bar['class']).to include('rounded-l-none', 'rounded-r-none')
    end

    it 'joins the two bars without round corners between them' do
      plug_bar, charge_bar = bars

      expect(charge_bar['class']).to include('rounded-r-none')
      expect(plug_bar['class']).to include('rounded-l-none')
    end
  end

  # The car was plugged in from the night before and again over the next
  # midnight
  context 'with a time plugged in over midnight' do
    let(:lanes) { [Car::DayTimeline::Lane.new(car:, drives: [], charges: [], soc_line: [], visits: [], plugged: [[at(0), at(7)], [at(23), at(0) + 1.day]])] }

    it 'leaves the end at midnight open' do
      night, evening = bars

      expect([night['aria-label'], evening['aria-label']]).to eq(['Plugged in, until 07:00', 'Plugged in, since 23:00'])
      expect([night, evening].map { it['class'][/rounded-\w-none/] }).to eq(%w[rounded-l-none rounded-r-none])
    end
  end

  # The car charged from the evening before until the night, and again from
  # the evening over the next midnight
  context 'with offsite sessions over midnight' do
    def night = ChargingSession.new(kind: :offsite, car_id: 1, started_at: at(22) - 1.day, ended_at: at(3), kwh: 30, cost: 9)

    def evening = ChargingSession.new(kind: :offsite, car_id: 1, started_at: at(22), ended_at: at(2) + 1.day, kwh: 20, cost: 6)

    let(:lanes) do
      charges = [Car::DayTimeline::Charge.new(session: night, spans: [[at(0), at(3)]]), Car::DayTimeline::Charge.new(session: evening, spans: [[at(22), at(0) + 1.day]])]
      [Car::DayTimeline::Lane.new(car:, drives: [], charges:, soc_line: [], visits: [])]
    end

    before { allow(vc_test_controller).to receive(:admin?).and_return(false) }

    it 'leaves the end at midnight open' do
      expect(bars.map { it['class'][/rounded-\w-none/] }).to eq(%w[rounded-l-none rounded-r-none])
      expect(bars.first['aria-label']).to include('Offsite charging, until 03:00')
      expect(bars.last['aria-label']).to include('Offsite charging, since 22:00')
    end

    it 'says that a charge from the day before counts there' do
      expect(bars.map { it['aria-label'].include?('Counts for the day on which it started') }).to eq([true, false])
    end
  end

  context 'with an offsite session without an end' do
    let(:session) { ChargingSession.new(kind: :offsite, car_id: 1, started_at: at(12), kwh: 30, cost: 9) }
    let(:lanes) { [Car::DayTimeline::Lane.new(car:, drives: [], charges: [Car::DayTimeline::Charge.new(session:, spans: [[at(12), at(14)]])], soc_line: [], visits: [])] }

    before { allow(vc_test_controller).to receive(:admin?).and_return(false) }

    it 'marks its time as an estimate, with a jagged end' do
      expect(bars.first['class']).to include('timeline-bar-estimated')
      expect(bars.first['aria-label']).to include("Offsite charging, #{range('12:00', '14:00')}", 'Time estimated, as recorded without an end')
    end
  end

  it 'has a placeholder in its height' do
    html = render_inline(described_class.placeholder)

    expect(html.css('.animate-pulse')).to be_present
    expect(html.css('[role="img"]')).to be_empty
  end
end
