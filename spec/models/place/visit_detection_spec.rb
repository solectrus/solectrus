describe Place::VisitDetection do
  subject(:detection) { described_class.new(dates) }

  let(:dates) { [Date.new(2026, 9, 22), Date.new(2026, 9, 23)] }
  let!(:car) { Car.create!(id: 1, active_from: Date.new(2026, 1, 1)) }
  let(:segments) do
    [
      # The night at home, about 9 m apart, over midnight
      segment('2026-09-21 18:00', '2026-09-22 07:00', 50.92263, 1.40706),
      segment('2026-09-22 07:00', '2026-09-22 07:20', 50.92270, 1.40710),
      # A traffic light
      segment('2026-09-22 07:20', '2026-09-22 07:25', 50.91000, 1.40000),
      # Work
      segment('2026-09-22 07:25', '2026-09-22 16:00', 50.90600, 1.40700),
      # Home again, until the next day
      segment('2026-09-22 16:00', '2026-09-23 08:00', 50.92263, 1.40706),
    ]
  end

  # The time between two readings of the car, the same for each segment
  let(:gap) { nil }

  def segment(from, to, latitude, longitude, gap: self.gap, odometer: nil)
    Sensor::Query::Positions::Segment.new(from: Time.zone.parse(from), to: Time.zone.parse(to), latitude:, longitude:, gap:, odometer:)
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

  # The permission opens the pages, the build does not ask for it
  it 'finds the stops also without the permission of the car sensors' do
    allow(ApplicationPolicy.instance).to receive(:feature_enabled?).and_return(false)

    expect(described_class).to be_enabled
    expect(detection.call[1]).to be_present
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
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 1.40706),
          # A wrong position
          segment('2026-09-22 08:00', '2026-09-22 08:15', 50.91000, 1.40000),
          segment('2026-09-22 08:15', '2026-09-22 09:00', 50.92263, 1.40706),
          # Past the work
          segment('2026-09-22 09:00', '2026-09-22 09:15', 50.90600, 1.40700),
          segment('2026-09-22 09:15', '2026-09-22 12:00', 50.95000, 1.45000),
          # Past the home
          segment('2026-09-22 12:00', '2026-09-22 12:15', 50.92263, 1.40706),
          segment('2026-09-22 12:15', '2026-09-23 00:00', 50.95000, 1.45000),
        ]
      end

      before { Place.create!(latitude: 50.906, longitude: 1.407) }

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

    # A stop of 20 minutes, shorter than Car::Rules::MIN_STAY
    context 'with a short stop' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 5.minutes }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 10:00', 50.92263, 1.40706),
          segment('2026-09-22 10:00', '2026-09-22 10:20', 50.91000, 1.40000),
          segment('2026-09-22 10:20', '2026-09-23 00:00', 50.92263, 1.40706),
        ]
      end

      it 'makes no place there, and joins the visits at home around it' do
        detection.persist(detection.call)

        expect(visits).to eq([[50.92263, '22. 00:00', '23. 00:00']])
        expect(Place.count).to eq(1)
      end

      context 'with a known place there, like a shop' do
        before { Place.create!(latitude: 50.91, longitude: 1.4) }

        it 'makes a visit' do
          detection.persist(detection.call)

          expect(visits).to include([50.91, '22. 10:00', '22. 10:20'])
        end
      end
    end

    # A car that reports every hour drove to a shop and back. Its one reading
    # at the shop is too short for a visit.
    context 'with a drive to a shop between two readings at home' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 1.hour }
      let(:segments) do
        [
          segment('2026-09-21 12:00', '2026-09-22 14:00', 50.92263, 1.40706, odometer: 100),
          segment('2026-09-22 14:00', '2026-09-22 15:00', 50.91000, 1.40000, odometer: 106),
          segment('2026-09-22 15:00', '2026-09-23 00:00', 50.92263, 1.40706, odometer: 112),
        ]
      end

      before { Place.create!(latitude: 50.91, longitude: 1.4) }

      it 'keeps the visits at home before and after it apart' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 14:00'],
            [50.92263, '22. 15:00', '23. 00:00'],
          ],
        )
      end

      # The odometer did not rise, so the reading at the shop was wrong
      context 'with a wrong position between them' do
        let(:segments) do
          [
            segment('2026-09-21 12:00', '2026-09-22 14:00', 50.92263, 1.40706, odometer: 100),
            segment('2026-09-22 14:00', '2026-09-22 15:00', 50.91000, 1.40000, odometer: 100),
            segment('2026-09-22 15:00', '2026-09-23 00:00', 50.92263, 1.40706, odometer: 100),
          ]
        end

        it 'joins the visits at home' do
          detection.persist(detection.call)

          expect(visits).to eq([[50.92263, '22. 00:00', '23. 00:00']])
        end
      end
    end

    context 'with a position every hour' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 1.hour }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 1.40706),
          # On the road
          segment('2026-09-22 08:00', '2026-09-22 09:00', 50.91000, 1.40000),
          segment('2026-09-22 09:00', '2026-09-22 12:00', 50.95000, 1.45000),
          # Past the home
          segment('2026-09-22 12:00', '2026-09-22 13:00', 50.92263, 1.40706),
          segment('2026-09-22 13:00', '2026-09-23 00:00', 50.95000, 1.45000),
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
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 1.40706),
          # The last reading before 3 hours without reception
          segment('2026-09-22 08:00', '2026-09-22 11:15', 50.91000, 1.40000),
          # The first reading after them, and a stop of 2 hours
          segment('2026-09-22 11:15', '2026-09-22 13:15', 50.95000, 1.45000, gap: 3.hours),
          segment('2026-09-22 13:15', '2026-09-23 00:00', 50.92263, 1.40706),
        ]
      end

      it 'takes the interval at the departure' do
        detection.persist(detection.call)

        expect(visits).to include([50.95, '22. 11:15', '22. 13:15'])
      end
    end

    # The car also repeats its position while it is parked, so each gap is
    # 10 minutes and a visit at a known place needs 15 minutes
    context 'with a car that reports every 10 minutes' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 10.minutes }
      let(:segments) do
        [
          segment('2026-09-21 18:00', '2026-09-22 10:00', 50.92263, 1.40706),
          segment('2026-09-22 10:00', '2026-09-22 10:10', 50.89000, 1.39000),
          # Past the shop
          segment('2026-09-22 10:10', '2026-09-22 10:20', 50.91000, 1.40000),
          segment('2026-09-22 10:20', '2026-09-22 10:30', 50.88000, 1.38000),
          # Work
          segment('2026-09-22 10:30', '2026-09-22 11:50', 50.90600, 1.40700),
          segment('2026-09-22 11:50', '2026-09-22 12:00', 50.89000, 1.39000),
          # A stop at the shop with two readings, at 12:00 and 12:10
          segment('2026-09-22 12:00', '2026-09-22 12:20', 50.91000, 1.40000),
          segment('2026-09-22 12:20', '2026-09-22 12:30', 50.89000, 1.39000),
          segment('2026-09-22 12:30', '2026-09-23 00:00', 50.92263, 1.40706),
        ]
      end

      before { Place.create!(latitude: 50.91, longitude: 1.40) }

      it 'makes a visit of the stop with two readings, and none of the drive past' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 10:00'],
            [50.906, '22. 10:30', '22. 11:50'],
            [50.91, '22. 12:00', '22. 12:20'],
            [50.92263, '22. 12:30', '23. 00:00'],
          ],
        )
      end
    end

    # The car repeats its position at home every 2.5 hours, and reports
    # every 15 minutes on the road, so the gap before its first reading on
    # the road is an interval of the readings at home
    context 'with a car that reports rarely while parked' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:segments) do
        [
          segment('2026-09-21 18:00', '2026-09-22 10:00', 50.92263, 1.40706, gap: nil),
          # Past the shop
          segment('2026-09-22 10:00', '2026-09-22 10:15', 50.91000, 1.40000, gap: 150.minutes),
          segment('2026-09-22 10:15', '2026-09-22 10:30', 50.89000, 1.39000, gap: 15.minutes),
          segment('2026-09-22 10:30', '2026-09-22 16:00', 50.90600, 1.40700, gap: 15.minutes),
        ]
      end

      before { Place.create!(latitude: 50.91, longitude: 1.40) }

      it 'makes no visit of the drive past a known place' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 10:00'],
            [50.906, '22. 10:30', '22. 16:00'],
          ],
        )
      end
    end

    # Each reading is a new place, and its gap is the time at the place before
    context 'with a car that reports only a change' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:segments) do
        [
          segment('2026-09-21 12:00', '2026-09-22 12:20', 50.92263, 1.40706, gap: nil),
          # A friend, for less than the 3 hours of the longest limit
          segment('2026-09-22 12:20', '2026-09-22 14:15', 50.92459, 1.36614, gap: (24.hours + 20.minutes)),
          segment('2026-09-22 14:15', '2026-09-22 15:00', 50.92263, 1.40706, gap: (1.hour + 55.minutes)),
        ]
      end

      # A car that also reports while it drives, like a Tesla
      context 'with readings on the road' do
        let(:segments) do
          [
            segment('2026-09-21 12:00', '2026-09-22 12:00', 50.92263, 1.40706, gap: nil),
            # The drive, a reading every 2 minutes, past the work
            segment('2026-09-22 12:00', '2026-09-22 12:02', 50.91500, 1.40000, gap: 24.hours),
            segment('2026-09-22 12:02', '2026-09-22 12:04', 50.90600, 1.40700, gap: 2.minutes),
            segment('2026-09-22 12:04', '2026-09-22 12:06', 50.89000, 1.39000, gap: 2.minutes),
            # The friend
            segment('2026-09-22 12:06', '2026-09-22 14:00', 50.92459, 1.36614, gap: 2.minutes),
          ]
        end

        before { Place.create!(latitude: 50.906, longitude: 1.407) }

        it 'leaves out each position of the drive' do
          detection.persist(detection.call)

          expect(visits).to eq(
            [
              [50.92263, '22. 00:00', '22. 12:00'],
              [50.92459, '22. 12:06', '22. 14:00'],
            ],
          )
        end
      end

      # The car moved within the place at home, like to a parking space some
      # meters away, so the gap before the next arrival covers only a part
      # of the stop at home
      context 'with a move within the stop before' do
        let(:segments) do
          [
            segment('2026-09-21 18:00', '2026-09-21 18:30', 50.92280, 1.40706, gap: nil),
            segment('2026-09-21 18:30', '2026-09-22 10:00', 50.92263, 1.40706, gap: 30.minutes),
            # The friend, for less than the 3 hours of the longest limit
            segment('2026-09-22 10:00', '2026-09-22 12:45', 50.92459, 1.36614, gap: 15.5.hours),
            segment('2026-09-22 12:45', '2026-09-22 15:00', 50.92263, 1.40706, gap: 165.minutes),
          ]
        end

        it 'makes a visit of the stop after it' do
          detection.persist(detection.call)

          expect(visits).to include([50.92459, '22. 10:00', '22. 12:45'])
        end
      end

      it 'makes a visit of a stop with one reading' do
        detection.persist(detection.call)

        expect(visits).to eq(
          [
            [50.92263, '22. 00:00', '22. 12:20'],
            [50.92459, '22. 12:20', '22. 14:15'],
            [50.92263, '22. 14:15', '22. 15:00'],
          ],
        )
      end
    end

    context 'when the car reports less often from noon on' do
      let(:dates) { [Date.new(2026, 9, 22)] }
      let(:gap) { 15.minutes }
      let(:segments) do
        [
          segment('2026-09-22 00:00', '2026-09-22 08:00', 50.92263, 1.40706),
          # The bakery, with four readings
          segment('2026-09-22 08:00', '2026-09-22 09:00', 50.91000, 1.40000),
          segment('2026-09-22 09:00', '2026-09-22 12:00', 50.92263, 1.40706),
          # On the road, with one reading
          segment('2026-09-22 12:00', '2026-09-22 13:00', 50.95000, 1.45000, gap: 1.hour),
          segment('2026-09-22 13:00', '2026-09-23 00:00', 50.92263, 1.40706, gap: 1.hour),
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
