describe Sensor::Chart::CarDistance do
  subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars: [Car.new(id: 1)]) }

  let(:today) { Date.new(2026, 9, 23) }

  before do
    travel_to today.in_time_zone.change(hour: 12)
    Sensor::Config.setup(
      ENV.to_h.merge(
        'INFLUX_SENSOR_CAR_ODOMETER_1' => 'Trabant:odometer',
        'INFLUX_SENSOR_CAR_ODOMETER_2' => 'Wartburg:odometer',
      ),
    )
    allow(Sensor::Config).to receive(:exists?).and_call_original
    allow(Sensor::Config).to receive(:exists?).with(:wallbox_power_grid).and_return(true)

    # 150 km in January on 30 kWh at home (10 kWh from the grid)
    summary(Date.new(2026, 1, 25), :wallbox_power, :sum, 30_000)
    summary(Date.new(2026, 1, 25), :wallbox_power_grid, :sum, 10_000)
    summary(Date.new(2026, 1, 25), :car_odometer_1, :sum, 150)

    # 50 km in March
    summary(Date.new(2026, 3, 20), :car_odometer_1, :sum, 50)

    # 30 km of the second car in March
    summary(Date.new(2026, 3, 21), :car_odometer_2, :sum, 30)
  end

  after { Sensor::Config.setup(ENV) }

  def summary(date, field, aggregation, value)
    Summary.find_or_create_by!(date:)
    SummaryValue.create!(date:, field:, aggregation:, value:)
  end

  # The energy sources split the charged energy, but not the distance: the
  # charge of a day says nothing about the energy of a drive.
  it 'has one dataset with the distance of each column, even with the power splitter' do
    dataset = chart.data[:datasets].sole

    expect(dataset[:id]).to eq('car_odometer_1')
    expect(dataset[:data].first(3)).to eq([150, nil, 50])
  end

  describe '.supports?' do
    it 'draws a day and longer' do
      expect(
        [Timeframe.new('2026-06-26'), Timeframe.new('2026-W26'), Timeframe.new('2026')].map do
          described_class.supports?(it)
        end,
      ).to all(be(true))
    end

    it 'does not draw the live view or hours' do
      expect([Timeframe.now, Timeframe.new('P1H')].map { described_class.supports?(it) }).to all(be(false))
    end
  end

  context 'with a day' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-09-22'), cars:) }

    let(:cars) { [Car.new(id: 1, active_from: Date.new(2020, 1, 1))] }

    before do
      influx_batch do
        [
          [Time.zone.local(2026, 9, 21, 22), 1000],
          [Time.zone.local(2026, 9, 22, 8), 1000],
          [Time.zone.local(2026, 9, 22, 9), 1030],
          [Time.zone.local(2026, 9, 22, 18), 1060],
          [Time.zone.local(2026, 9, 23, 6), 1072],
        ].each do |time, value|
          add_influx_point(name: 'Trabant', fields: { odometer: value.to_f }, time:)
        end
      end
    end

    def value_at(hour, minute)
      data = chart.data
      data[:datasets].sole[:data][data[:labels].index(Time.zone.local(2026, 9, 22, hour, minute).to_i * 1000)]
    end

    # The 12 km after 18:00 go to the next day, as in the daily summary
    it 'draws the distance since midnight as a line that ends at the distance of the day' do
      dataset = chart.data[:datasets].sole

      expect(chart.type).to eq('line')
      expect(dataset[:data].first).to eq(0)
      expect(value_at(9, 5)).to eq(30)
      expect(dataset[:data].last).to eq(60)
    end

    # The odometer is a state, so the 30 km of 09:00 do not ramp from 08:00
    it 'holds each reading until the next one, like the daily summary' do
      expect(value_at(8, 30)).to eq(0)
      expect(value_at(17, 30)).to eq(30)
      expect(chart.data[:datasets].sole[:stepped]).to be(true)
    end

    it 'has no notes without a visit' do
      expect(chart.data[:datasets].sole).not_to have_key(:tooltipRowNotes)
    end

    context 'with visits' do
      subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-09-22'), cars:, admin: true) }

      let(:home) { Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Garage', labels: ['home']) }
      let(:work) { Place.create!(latitude: 50.906, longitude: 6.407) }

      before do
        car = Car.configured.find { it.id == 1 }
        [[home, 0, 8], [work, 9, 18]].each do |place, from, to|
          place.visits.create!(car:, date: Date.new(2026, 9, 22), started_at: Time.zone.local(2026, 9, 22, from), ended_at: Time.zone.local(2026, 9, 22, to))
        end
      end

      def note_at(hour, minute)
        data = chart.data
        data[:datasets].sole[:tooltipRowNotes][data[:labels].index(Time.zone.local(2026, 9, 22, hour, minute).to_i * 1000)]
      end

      it 'notes the place of the car at each time, and nothing between the visits' do
        expect([note_at(7, 55), note_at(8, 30), note_at(12, 0), note_at(20, 0)]).to eq(
          [{ text: 'Garage', icon: 'house' }, nil, { text: 'Unknown place', icon: 'location-dot' }, nil],
        )
      end

      it 'gives the markup of each icon once' do
        expect(chart.data[:datasets].sole[:tooltipIcons].transform_values { it[/data-icon="([^"]+)"/, 1] }).to eq(
          'house' => 'house', 'location-dot' => 'location-dot',
        )
      end

      # Only the admin sees the places
      context 'with a guest' do
        subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-09-22'), cars:) }

        it 'has no notes' do
          expect(chart.data[:datasets].sole).not_to include(:tooltipRowNotes, :tooltipIcons)
        end
      end

      it 'draws a line of each car on its own' do
        expect(chart.data[:datasets].sole).not_to include(:stack, :summed)
      end
    end

    context 'with two cars on the same day' do
      subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-09-22'), cars: Car.configured, admin: true) }

      let(:home) { Place.create!(latitude: 50.92263, longitude: 6.40706, name: 'Garage', labels: ['home']) }
      let(:work) { Place.create!(latitude: 50.906, longitude: 6.407) }

      before do
        Car.create!(id: 2, name: 'Wartburg', color: '#ff0000')

        influx_batch do
          [
            [Time.zone.local(2026, 9, 21, 23), 500],
            [Time.zone.local(2026, 9, 22, 10), 520],
            [Time.zone.local(2026, 9, 23, 6), 520],
          ].each do |time, value|
            add_influx_point(name: 'Wartburg', fields: { odometer: value.to_f }, time:)
          end
        end

        trabant, wartburg = Car.configured
        [[trabant, home, 0, 8], [wartburg, work, 0, 9]].each do |car, place, from, to|
          place.visits.create!(car:, date: Date.new(2026, 9, 22), started_at: Time.zone.local(2026, 9, 22, from), ended_at: Time.zone.local(2026, 9, 22, to))
        end
      end

      # The index of 07:55 in the labels, which both lines share
      def index_at_7_55
        chart.data[:labels].index(Time.zone.local(2026, 9, 22, 7, 55).to_i * 1000)
      end

      it 'draws a line of each car, with its name, tinted with its color' do
        datasets = chart.data[:datasets]

        expect(datasets.pluck(:label)).to eq(['Car 1', 'Wartburg'])
        expect(datasets.pluck(:tintColor)).to eq([Car::DEFAULT_COLOR, '#ff0000'])
        expect(datasets.map { it[:data].last }).to eq([60, 20])
        expect(datasets.flat_map(&:keys)).not_to include(:stack, :summed)
      end

      it 'notes the place of each car at the same time' do
        expect(chart.data[:datasets].map { it[:tooltipRowNotes][index_at_7_55] }).to eq(
          [{ text: 'Garage', icon: 'house' }, { text: 'Unknown place', icon: 'location-dot' }],
        )
      end
    end

    context 'with a 0 of an offline car' do
      before do
        influx_batch { add_influx_point(name: 'Trabant', fields: { odometer: 0.0 }, time: Time.zone.local(2026, 9, 22, 12)) }
      end

      # The line holds 30 km from 09:05 to 18:05 instead
      it 'skips it' do
        expect(value_at(12, 5)).to eq(30)
        expect(chart.data[:datasets].sole[:data].last).to eq(60)
      end
    end

    context 'with a car outside its period of use' do
          let(:cars) { [Car.new(id: 1, active_from: Date.new(2026, 9, 23))] }

          it 'has no data' do
            expect(chart.data).to be_nil
          end
    end

    # The installation date has no reading at its start, so its summary has
    # no distance
    context 'with the installation date' do
      subject(:chart) { described_class.new(timeframe: Timeframe.new(date.iso8601), cars:) }

      let(:date) { Rails.configuration.x.installation_date }

      before do
        influx_batch do
          [[date.in_time_zone.change(hour: 8), 42_000], [date.in_time_zone.change(hour: 18), 42_060]].each do |time, value|
            add_influx_point(name: 'Trabant', fields: { odometer: value.to_f }, time:)
          end
        end
      end

      it 'draws no line instead of the odometer' do
        expect(chart.data[:datasets].sole[:data].compact).to be_empty
      end
    end
  end

  context 'with a month without a drive' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026-02'), cars: [Car.new(id: 1)]) }

    # A parked car has a distance of 0
    before { summary(Date.new(2026, 2, 10), :car_odometer_1, :sum, 0) }

    it 'is blank and shows a road instead of a message' do
      expect(chart).to be_blank
      expect(chart.blank_message).to eq(I18n.t('data.car_no_driving'))
      expect(chart.blank_icon).to eq('road')
    end
  end

  it 'does not stack the columns' do
    expect(chart.options.dig(:scales, :y, :stacked)).to be_falsy
  end

  context 'with all cars' do
    subject(:chart) { described_class.new(timeframe: Timeframe.new('2026'), cars: Car.configured) }

    before { Car.create!(id: 2, name: 'Wartburg', color: '#ff0000') }

    it 'stacks a part for each car, with its name, tinted with its color' do
      datasets = chart.data[:datasets]

      expect(datasets.pluck(:label)).to eq(['Car 1', 'Wartburg'])
      expect(datasets.pluck(:tintColor)).to eq([Car::DEFAULT_COLOR, '#ff0000'])
      expect(datasets.map { it[:data][2] }).to eq([50, 30])
      expect(datasets.pluck(:stack).uniq).to eq(['CarDistance'])
      expect(datasets.pluck(:summed)).to all(be(true))
    end
  end
end
