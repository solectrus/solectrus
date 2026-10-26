describe Car::DayTimeline::Axis do
  subject(:axis) { described_class.new(Timeframe.new('2026-06-15')) }

  def at(hour, minute = 0) = Time.zone.local(2026, 6, 15, hour, minute)

  it 'places a time in percent of the day' do
    expect([at(0), at(6), at(18), at(0) + 1.day].map { axis.position(it) }).to eq([0.0, 25.0, 75.0, 100.0])
  end

  it 'ends the day at 24:00' do
    expect(axis.range(at(22, 5), at(0) + 1.day)).to eq("22:05\u202F–\u202F24:00")
  end

  it 'has no now on a past day' do
    expect(axis.now).to be_nil
  end

  # The clock changed on this day, so it has 23 hours
  context 'with a day of the change to summer time' do
    subject(:axis) { described_class.new(Timeframe.new('2026-03-29')) }

    it 'spreads 23 hours over the day' do
      expect(axis.position(Time.zone.local(2026, 3, 29, 12))).to eq((11 * 100.0 / 23).round(3))
    end
  end

  context 'with the running day' do
    before { travel_to at(18) }

    it 'places now, and the labels near it give way' do
      expect(axis.now).to eq(75.0)
      expect(axis.ticks[6].to_h.slice(:label, :desktop, :phone)).to eq(label: '18:00', desktop: false, phone: false)
    end
  end
end
