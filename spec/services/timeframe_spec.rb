describe Timeframe do
  subject(:decoder) do
    described_class.new(
      string,
      min_date: Date.new(2019, 5, 2),
      allowed_days_in_future: 1,
    )
  end

  let(:today) { Date.new(2022, 10, 13) }

  before { travel_to today.to_time.change(hour: 10) }

  describe 'static methods' do
    describe '.now' do
      subject { described_class.now }

      it { is_expected.to be_now }
    end

    describe '.all' do
      subject { described_class.all }

      it { is_expected.to be_all }
    end

    describe '.day' do
      subject { described_class.day }

      it { is_expected.to be_day }
      it { is_expected.to be_current }
    end

    describe '.week' do
      subject { described_class.week }

      it { is_expected.to be_week }
      it { is_expected.to be_current }
    end

    describe '.month' do
      subject { described_class.month }

      it { is_expected.to be_month }
      it { is_expected.to be_current }
    end

    describe '.year' do
      subject { described_class.year }

      it { is_expected.to be_year }
      it { is_expected.to be_current }
    end

    describe '.regex' do
      subject { described_class::REGEX }

      it { is_expected.to match('2022-02-02') }
      it { is_expected.to match('2022-W42') }
      it { is_expected.to match('2022-02') }
      it { is_expected.to match('2022') }
      it { is_expected.to match('now') }
      it { is_expected.to match('day') }
      it { is_expected.to match('week') }
      it { is_expected.to match('month') }
      it { is_expected.to match('year') }
      it { is_expected.to match('all') }

      it { is_expected.not_to match('foo') }
      it { is_expected.not_to match('42') }
    end
  end

  context 'when string is "now"' do
    let(:string) { 'now' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:now)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2022-10-13 10:00:00 +0200')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-10-13 10:00:00 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-10-13 10:00:00 +0200')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next).to be_nil
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev).to be_nil
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('10:00')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2022-10-13')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2022-W41')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2022-10')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(true)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(true)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(false)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'is starts_today' do
      expect(decoder.starts_today?).to be(true)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'cannot paginate' do
      expect(decoder.can_paginate?).to be(false)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a day in the past' do
    let(:string) { '2022-05-13' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:day)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2022-05-13 00:00:00.000000000 +0200')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-05-13 23:59:59.999999999 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-05-14 00:00:00 +0200')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2022-05-14')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2022-05-12')
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('Friday, 13. May 2022')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq(string)
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2022-W19')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2022-05')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(true)
      expect(decoder.short?).to be(true)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(false)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is past' do
      expect(decoder.past?).to be(true)
    end

    it 'is not today' do
      expect(decoder.today?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 1 day' do
      expect(decoder.days_passed).to eq(1)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a day in the future' do
    let(:string) { '2022-10-14' }

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is future' do
      expect(decoder.future?).to be(true)
    end

    it 'is not today' do
      expect(decoder.today?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 0 days' do
      expect(decoder.days_passed).to eq(0)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is first day of the year' do
    let(:string) { '2022-01-01' }

    it 'returns the corresponding_week with week-based year' do
      expect(decoder.corresponding_week).to eq('2021-W52')
    end
  end

  context 'when string is current day' do
    let(:string) { today.to_s }

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'is starts_today' do
      expect(decoder.starts_today?).to be(true)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'is today' do
      expect(decoder.today?).to be(true)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 0 days' do
      expect(decoder.days_passed).to eq(0)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is "day"' do
    let(:string) { 'day' }

    it 'is current day' do
      expect(decoder.current?).to be(true)
      expect(decoder.day?).to be(true)
    end

    it 'is starts_today' do
      expect(decoder.starts_today?).to be(true)
    end

    it 'is today' do
      expect(decoder.today?).to be(true)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 0 days' do
      expect(decoder.days_passed).to eq(0)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a week in the past' do
    let(:string) { '2022-W19' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:week)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2022-05-09 00:00:00.000000000 +0200')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-05-15 23:59:59.999999999 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-05-16 00:00:00 +0200')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2022-W20')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2022-W18')
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('CW 19, 2022')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2022-05-15')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq(string)
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2022-05')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(false)
      expect(decoder.week?).to be(true)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(false)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is past' do
      expect(decoder.past?).to be(true)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 7 days' do
      expect(decoder.days_passed).to eq(7)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a week in the future' do
    let(:string) { '2022-W42' }

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is future' do
      expect(decoder.future?).to be(true)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 0 days' do
      expect(decoder.days_passed).to eq(0)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is current week' do
    let(:string) { '2022-W41' }

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 3 days' do
      expect(decoder.days_passed).to eq(3)
    end

    context "when it's the first day" do
      let(:today) { Date.new(2022, 10, 10) }

      it 'is starts_today' do
        expect(decoder.starts_today?).to be(true)
      end
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is "week"' do
    let(:string) { 'week' }

    it 'is current week' do
      expect(decoder.current?).to be(true)
      expect(decoder.week?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a week at end of year' do
    let(:string) { '2020-W50' }

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2020-W51')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2020-W49')
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a week at min_date' do
    let(:string) { '2019-W19' }

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2019-W20')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2019-W18')
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a month' do
    let(:string) { '2022-05' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:month)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2022-05-01 00:00:00.000000000 +0200')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-05-31 23:59:59.999999999 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-06-01 00:00:00 +0200')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2022-06')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2022-04')
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('May 2022')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2022-05-31')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2022-W22')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq(string)
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(false)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(true)
      expect(decoder.year?).to be(false)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 31 days' do
      expect(decoder.days_passed).to eq(31)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a month at min_date' do
    let(:string) { '2019-06' }

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2019-07')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2019-05')
    end

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is past' do
      expect(decoder.past?).to be(true)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a month in the future' do
    let(:string) { '2022-11' }

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is future' do
      expect(decoder.future?).to be(true)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 0 days' do
      expect(decoder.days_passed).to eq(0)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is current month' do
    let(:string) { '2022-10' }

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 12 days' do
      expect(decoder.days_passed).to eq(12)
    end

    context "when it's the first day" do
      let(:today) { Date.new(2022, 10, 1) }

      it 'is starts_today' do
        expect(decoder.starts_today?).to be(true)
      end
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is "month"' do
    let(:string) { 'month' }

    it 'is current month' do
      expect(decoder.current?).to be(true)
      expect(decoder.month?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a year' do
    let(:string) { '2021' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:year)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2021-01-01 00:00:00.000000000 +0100')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2021-12-31 23:59:59.999999999 +0100')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-01-01 00:00:00 +0100')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2022')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2020')
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('2021')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2021-12-31')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2021-W52')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2021-12')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq(string)
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(false)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(true)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is past' do
      expect(decoder.past?).to be(true)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 365 days' do
      expect(decoder.days_passed).to eq(365)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is future year' do
    let(:string) { '2023' }

    it 'is not current' do
      expect(decoder.current?).to be(false)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is future' do
      expect(decoder.future?).to be(true)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 0 days' do
      expect(decoder.days_passed).to eq(0)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is current year' do
    let(:string) { '2022' }

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'has passed 285 days' do
      expect(decoder.days_passed).to eq(285)
    end

    context "when it's the first day" do
      let(:today) { Date.new(2022, 1, 1) }

      it 'is starts_today' do
        expect(decoder.starts_today?).to be(true)
      end
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is "year"' do
    let(:string) { 'year' }

    it 'is current year' do
      expect(decoder.current?).to be(true)
      expect(decoder.year?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is a year at min_date' do
    let(:string) { '2020' }

    it 'returns the correct next timeframe' do
      expect(decoder.next.to_s).to eq('2021')
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev.to_s).to eq('2019')
    end

    it 'can paginate' do
      expect(decoder.can_paginate?).to be(true)
    end

    it 'is not relative' do
      expect(decoder.relative?).to be(false)
    end
  end

  context 'when string is some days' do
    let(:string) { 'P3D' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:days)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct iso6081' do
      expect(decoder.iso8601).to eq('P3D')
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2022-10-11 00:00:00.000000000 +0200')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-10-13 23:59:59.999999999 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-10-14 00:00:00 +0200')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next).to be_nil
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev).to be_nil
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('Last 3 days')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2022-10-13')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2022-W41')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2022-10')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(false)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(false)
      expect(decoder.days?).to be(true)
      expect(decoder.months?).to be(false)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'does not start today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'cannot paginate' do
      expect(decoder.can_paginate?).to be(false)
    end

    it 'has passed 2 days' do
      expect(decoder.days_passed).to eq(2)
    end

    it 'is relative' do
      expect(decoder.relative?).to be(true)
    end
  end

  context 'when string is some months' do
    let(:string) { 'P12M' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:months)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct iso6081' do
      expect(decoder.iso8601).to eq('P12M')
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2021-11-01 00:00:00.000000000 +0100')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-10-13 23:59:59.999999999 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-11-01 00:00:00 +0100')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next).to be_nil
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev).to be_nil
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('Last 12 months')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2022-10-13')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2022-W41')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2022-10')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(false)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(false)
      expect(decoder.days?).to be(false)
      expect(decoder.months?).to be(true)
      expect(decoder.all?).to be(false)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'does not start today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'cannot paginate' do
      expect(decoder.can_paginate?).to be(false)
    end

    it 'has passed 346 days' do
      expect(decoder.days_passed).to eq(346)
    end

    it 'is relative' do
      expect(decoder.relative?).to be(true)
    end
  end

  context 'when string is "all"' do
    let(:string) { 'all' }

    it 'returns the correct id' do
      expect(decoder.id).to eq(:all)
    end

    it 'returns the correct to_s' do
      expect(decoder.to_s).to eq(string)
    end

    it 'returns the correct beginning' do
      expect(decoder.beginning).to eq('2019-01-01 00:00:00.000000000 +0100')
    end

    it 'returns the correct ending' do
      expect(decoder.ending).to eq('2022-10-13 23:59:59.999999999 +0200')
    end

    it 'returns the correct beginning_of_next' do
      expect(decoder.beginning_of_next).to eq('2022-10-14 00:00:00 +0200')
    end

    it 'returns the correct next timeframe' do
      expect(decoder.next).to be_nil
    end

    it 'returns the correct previous timeframe' do
      expect(decoder.prev).to be_nil
    end

    it 'returns the correct localized' do
      expect(decoder.localized).to eq('Since commissioning over 3 years ago')
    end

    it 'returns the correct corresponding_day' do
      expect(decoder.corresponding_day).to eq('2022-10-13')
    end

    it 'returns the correct corresponding_week' do
      expect(decoder.corresponding_week).to eq('2022-W41')
    end

    it 'returns the correct corresponding_month' do
      expect(decoder.corresponding_month).to eq('2022-10')
    end

    it 'returns the correct corresponding_year' do
      expect(decoder.corresponding_year).to eq('2022')
    end

    it 'returns the correct inquirer' do
      expect(decoder.now?).to be(false)
      expect(decoder.day?).to be(false)
      expect(decoder.short?).to be(false)
      expect(decoder.week?).to be(false)
      expect(decoder.month?).to be(false)
      expect(decoder.year?).to be(false)
      expect(decoder.all?).to be(true)
    end

    it 'is not out_of_range' do
      expect(decoder.out_of_range?).to be(false)
    end

    it 'is current' do
      expect(decoder.current?).to be(true)
    end

    it 'is not starts_today' do
      expect(decoder.starts_today?).to be(false)
    end

    it 'is not past' do
      expect(decoder.past?).to be(false)
    end

    it 'is not future' do
      expect(decoder.future?).to be(false)
    end

    it 'cannot paginate' do
      expect(decoder.can_paginate?).to be(false)
    end

    it 'has passed 1260 days' do
      # 2019-05-02 (min_ate) to 2022-10-13 (current date) = 1260 days
      expect(decoder.days_passed).to eq(1260)
    end
  end

  context 'when string is invalid' do
    %w[foo 123 2022-09-99 2022-99-09 2022-99 2022-W99].each do |string|
      context "when given #{string}" do
        let(:string) { string }

        it 'raises an error' do
          expect { decoder.beginning }.to raise_error(ArgumentError)
        end
      end
    end
  end

  context 'when date is after max_date' do
    let(:string) { '2022-10-15' }

    it 'is out_of_range' do
      expect(decoder.out_of_range?).to be(true)
    end
  end

  context 'when week is after max_date' do
    let(:string) { '2022-W42' }

    it 'is out_of_range' do
      expect(decoder.out_of_range?).to be(true)
    end
  end

  context 'when date is before min_date' do
    let(:string) { '2019-05-01' }

    it 'is out_of_range' do
      expect(decoder.out_of_range?).to be(true)
    end
  end
end
