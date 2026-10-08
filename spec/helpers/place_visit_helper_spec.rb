describe PlaceVisitHelper do
  def visit_from(from, to, ongoing: false)
    PlaceVisit.new(started_at: Time.zone.parse(from), ended_at: Time.zone.parse(to), ongoing:)
  end

  describe '#visit_time_range' do
    def range(from, to) = helper.visit_time_range(visit_from(from, to))

    it 'names the times of a visit on one day' do
      expect(range('2026-10-06 07:18', '2026-10-06 13:39')).to eq('07:18–13:39')
    end

    it 'names the day of the end of a visit over midnight' do
      expect(range('2026-10-05 16:57', '2026-10-06 07:18')).to eq('16:57 – 06.10. 07:18')
    end

    it 'names the year of the end when the year changes' do
      expect(range('2026-12-31 18:00', '2027-01-01 09:30')).to eq('18:00 – 01.01.2027 09:30')
    end

    it 'names no end of an ongoing visit' do
      expect(helper.visit_time_range(visit_from('2026-10-05 16:57', '2026-10-06 15:13', ongoing: true))).to eq('since 16:57')
    end
  end

  describe '#visit_day_times' do
    let(:day) { Date.new(2026, 10, 6) }

    def day_times(from, to, ongoing: false) = helper.visit_day_times(visit_from(from, to, ongoing:), day)

    it 'names only the times of a visit on the day' do
      expect(day_times('2026-10-06 07:18', '2026-10-06 13:39')).to eq(['07:18–13:39', nil])
    end

    it 'names the end of a visit from the day before, and its start below' do
      expect(day_times('2026-10-05 16:57', '2026-10-06 07:18')).to eq(['until 07:18', 'since 05.10. 16:57'])
    end

    it 'names the start of a visit into the next day, and its end below' do
      expect(day_times('2026-10-06 22:10', '2026-10-07 06:30')).to eq(['from 22:10', 'until 07.10. 06:30'])
    end

    it 'names a visit over the whole day, and its start and end below' do
      expect(day_times('2026-10-05 18:00', '2026-10-07 08:00')).to eq(['all day', '05.10. 18:00 – 07.10. 08:00'])
    end

    it 'names no end of an ongoing visit on the day' do
      expect(day_times('2026-10-06 13:39', '2026-10-06 15:13', ongoing: true)).to eq(['since 13:39', nil])
    end

    it 'names an ongoing visit from the day before as all day, and its start below' do
      expect(day_times('2026-10-05 16:57', '2026-10-06 15:13', ongoing: true)).to eq(['all day', 'since 05.10. 16:57'])
    end

    it 'names no end of an ongoing visit into the next day' do
      expect(day_times('2026-10-06 22:10', '2026-10-07 15:13', ongoing: true)).to eq(['from 22:10', 'until now'])
    end
  end
end
