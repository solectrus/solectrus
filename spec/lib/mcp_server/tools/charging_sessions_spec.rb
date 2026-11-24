describe McpServer::Tools::ChargingSessions do
  def call(**args)
    response = described_class.call(server_context: nil, **args)
    text = response.content.first[:text]

    response.error? ? [true, text] : [false, JSON.parse(text, symbolize_names: true)]
  end

  def answer(**args)
    error, data = call(**args)
    expect(error).to be(false), "Unexpected error: #{data}"

    data
  end

  def session(day, kind: :wallbox, origin: :detection, hour: 12, **attributes)
    started_at = Time.zone.local(2026, 1, day, hour)
    ChargingSession.create!(kind:, origin:, started_at:, ended_at: started_at + 1.hour, **attributes)
  end

  let!(:car) { Car.create!(id: 1, active_from: Date.new(2025, 1, 1)) }

  before do
    # The address keeps its text without Nominatim
    allow(Place::Nominatim).to receive(:enabled?).and_return(false)

    session(10, kwh: 10, cost: 1.6, car:)
    session(11, kwh: 5, guest: true)
    session(12, kwh: 7)
    session(13, kind: :offsite, origin: :mcp, kwh: 8, cost: 4.0, car:, provider: 'Provider A', address: 'Main Street 15, 12345 Town')
  end

  it 'is available with a car' do
    expect(described_class.available?).to be(true)
  end

  it 'lists the charges newest first, each with how it counts and who wrote it' do
    data = answer

    expect(data).to include(currency: Rails.configuration.x.currency, total_count: 4)
    expect(data[:charges].pluck(:state)).to eq(%w[car unassigned guest car])
    expect(data[:charges].first).to eq(
      id: ChargingSession.offsite.sole.id,
      kind: 'offsite',
      state: 'car',
      car: 1,
      started_at: '2026-01-13T12:00:00+01:00',
      ended_at: '2026-01-13T13:00:00+01:00',
      kwh: 8.0,
      cost: 4.0,
      provider: 'Provider A',
      origin: 'mcp',
    )
  end

  it 'gives the address and the position only while locations are allowed' do
    expect(answer[:charges].first).not_to include(:address)

    Setting.mcp_locations = true
    expect(answer[:charges].first).to include(address: 'Main Street 15, 12345 Town')
  end

  # A proposal does not count until someone confirms it. A dismissed one keeps
  # its row with the mark, and the list of the browser leaves it out too.
  it 'names a proposal and leaves out a dismissed one' do
    proposals = [14, 15].map do |day|
      started_at = Time.zone.local(2026, 1, day, 12)
      { kind: 'offsite', origin: 'detection', car_id: 1, started_at:, ended_at: started_at + 1.hour, kwh: 6, dismissed: day == 15, assigned_manually: day == 15 }
    end
    ChargingSession.insert_all!(proposals)

    expect(answer(kind: 'offsite')[:charges].pluck(:started_at, :state)).to eq(
      [%w[2026-01-14T12:00:00+01:00 proposal], %w[2026-01-13T12:00:00+01:00 car]],
    )
  end

  it 'joins a charge over midnight into one, like the list of the browser' do
    midnight = Time.zone.local(2026, 1, 21)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: midnight - 2.hours, ended_at: midnight - 1.second, kwh: 6)
    ChargingSession.create!(kind: :wallbox, origin: :detection, car:, started_at: midnight, ended_at: midnight + 3.hours, kwh: 15)

    data = answer(from: '2026-01-20')

    expect(data[:total_count]).to eq(1)
    expect(data[:charges].sole).to include(started_at: '2026-01-20T22:00:00+01:00', ended_at: '2026-01-21T03:00:00+01:00', kwh: 21.0)
  end

  it 'filters by car, kind and dates' do
    expect(answer(car: 1)[:charges].pluck(:kwh)).to eq([8.0, 10.0])
    expect(answer(kind: 'wallbox')[:total_count]).to eq(3)
    expect(answer(from: '2026-01-11', to: '2026-01-12')[:charges].pluck(:kwh)).to eq([7.0, 5.0])
  end

  it 'counts all matching charges while it limits the list' do
    data = answer(limit: 1)

    expect(data[:charges].size).to eq(1)
    expect(data[:total_count]).to eq(4)
  end

  it 'names swapped dates' do
    error, text = call(from: '2026-01-12', to: '2026-01-11')

    expect(error).to be(true)
    expect(text).to include('Use from=2026-01-11, to=2026-01-12')
  end
end
