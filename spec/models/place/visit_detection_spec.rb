describe Place::VisitDetection do
  subject(:detection) { described_class.new(dates) }

  let(:dates) { [Date.new(2026, 9, 22), Date.new(2026, 9, 23)] }
  let!(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:segments) do
    [
      # The night at home, about 9 m apart, over midnight
      segment('2026-09-21 18:00', '2026-09-22 07:00', 50.92263, 6.40706),
      segment('2026-09-22 07:00', '2026-09-22 07:20', 50.92270, 6.40710),
      # A traffic light
      segment('2026-09-22 07:20', '2026-09-22 07:25', 50.91000, 6.40000),
      # Work
      segment('2026-09-22 07:25', '2026-09-22 16:00', 50.90600, 6.40700),
      # Home again, until the next day
      segment('2026-09-22 16:00', '2026-09-23 08:00', 50.92263, 6.40706),
    ]
  end

  # The time between two readings of the car, the same for each segment
  let(:gap) { nil }

  def segment(from, to, latitude, longitude, gap: self.gap)
    Sensor::Query::Positions::Segment.new(from: Time.zone.parse(from), to: Time.zone.parse(to), latitude:, longitude:, gap:)
  end

  def visits
    PlaceVisit.includes(:place).order(:started_at).map do
      [it.place.latitude, it.started_at.strftime('%d. %H:%M'), it.ended_at.strftime('%d. %H:%M')]
    end
  end

  before do
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_LATITUDE_1' => 'Trabant:latitude',
        'INFLUX_SENSOR_CAR_LONGITUDE_1' => 'Trabant:longitude',
      ),
    )
    allow(Sensor::Query::Positions).to receive(:new).and_return(instance_double(Sensor::Query::Positions, call: segments))
  end

  after { Sensor::Config.setup(ENV) }

  it 'is enabled with the location of a car' do
    expect(described_class).to be_enabled
  end

  # Without the permission, the query gives no position, so the step would
  # remove the visits of its days
  it 'waits without the permission of the car sensors' do
    stub_feature

    expect(described_class).not_to be_enabled
  end

  describe '#call' do
    it 'joins the following positions within the radius into stops' do
      stops = detection.call[1]

      expect(stops.map { [it.latitude, it.from.strftime('%d. %H:%M'), it.to.strftime('%d. %H:%M')] }).to eq(
        [
          [50.92263, '21. 18:00', '22. 07:20'],
          [50.91000, '22. 07:20', '22. 07:25'],
          [50.90600, '22. 07:25', '22. 16:00'],
          [50.92263, '22. 16:00', '23. 08:00'],
        ],
      )
    end

    it 'reads the longest limit before the first day and after the last day' do
      detection.call

      expect(Sensor::Query::Positions).to have_received(:new).with(
        hash_including(period: Time.zone.parse('2026-09-21 21:00')..Time.zone.parse('2026-09-24 03:00')),
      )
    end
  end

  describe '#persist' do
    it 'writes the visits of the days, cut at midnight, without the short stop at no place' do
      detection.persist(detection.call)

      expect(visits).to eq(
        [
          [50.92263, '22. 00:00', '22. 07:20'],
          [50.906, '22. 07:25', '22. 16:00'],
          [50.92263, '22. 16:00', '23. 00:00'],
          [50.92263, '23. 00:00', '23. 08:00'],
        ],
      )
      expect(Place.count).to eq(2)
    end

    it 'replaces the visits of its days' do
      2.times { detection.persist(detection.call) }

      expect(PlaceVisit.count).to eq(4)
    end

    context 'with a position every 15 minutes' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 15.minutes }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 6.40706),
          # A wrong position
          segment('2026-09-22 08:00', '2026-09-22 08:15', 50.91000, 6.40000),
          segment('2026-09-22 08:15', '2026-09-22 09:00', 50.92263, 6.40706),
          # Past the work
          segment('2026-09-22 09:00', '2026-09-22 09:15', 50.90600, 6.40700),
          segment('2026-09-22 09:15', '2026-09-22 12:00', 50.95000, 6.45000),
          # Past the home
          segment('2026-09-22 12:00', '2026-09-22 12:15', 50.92263, 6.40706),
          segment('2026-09-22 12:15', '2026-09-23 00:00', 50.95000, 6.45000),
        ]
      end

      before { Place.create!(latitude: 50.906, longitude: 6.407) }

      it 'leaves out each drive past a place, and joins the visits around it' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 09:00'],
            [50.95, '22. 09:15', '23. 00:00'],
          ],
        )
      end
    end

    context 'with a position every hour' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 1.hour }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 6.40706),
          # On the road
          segment('2026-09-22 08:00', '2026-09-22 09:00', 50.91000, 6.40000),
          segment('2026-09-22 09:00', '2026-09-22 12:00', 50.95000, 6.45000),
          # Past the home
          segment('2026-09-22 12:00', '2026-09-22 13:00', 50.92263, 6.40706),
          segment('2026-09-22 13:00', '2026-09-23 00:00', 50.95000, 6.45000),
        ]
      end

      it 'needs 90 minutes for a visit and for a new place' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 08:00'],
            [50.95, '22. 09:00', '23. 00:00'],
          ],
        )
        expect(Place.count).to eq(2)
      end
    end

    context 'with a time without reception before the arrival' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 15.minutes }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 6.40706),
          # The last reading before 3 hours without reception
          segment('2026-09-22 08:00', '2026-09-22 11:15', 50.91000, 6.40000),
          # The first reading after them, and a stop of 2 hours
          segment('2026-09-22 11:15', '2026-09-22 13:15', 50.95000, 6.45000, gap: 3.hours),
          segment('2026-09-22 13:15', '2026-09-23 00:00', 50.92263, 6.40706),
        ]
      end

      it 'takes the interval at the departure' do
        detection.persist(detection.call)

        expect(visits).to include([50.95, '22. 11:15', '22. 13:15'])
      end
    end

    context 'when the car reports less often from noon on' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 15.minutes }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 6.40706),
          # The bakery, with four readings
          segment('2026-09-22 08:00', '2026-09-22 09:00', 50.91000, 6.40000),
          segment('2026-09-22 09:00', '2026-09-22 12:00', 50.92263, 6.40706),
          # On the road, with one reading
          segment('2026-09-22 12:00', '2026-09-22 13:00', 50.95000, 6.45000, gap: 1.hour),
          segment('2026-09-22 13:00', '2026-09-23 00:00', 50.92263, 6.40706, gap: 1.hour),
        ]
      end

      it 'takes the interval at each arrival' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 08:00'],
            [50.91, '22. 08:00', '22. 09:00'],
            [50.92263, '22. 09:00', '22. 12:00'],
            [50.92263, '22. 13:00', '23. 00:00'],
          ],
        )
        expect(Place.count).to eq(2)
      end
    end
  end

  context 'with a car outside its period of use' do
    before { car.update!(active_until: dates.first) }

    it 'gives the car no visit on the day after' do
      detection.persist(detection.call)

      expect(PlaceVisit.distinct.pluck(:date)).to eq([dates.first])
    end
  end
end
