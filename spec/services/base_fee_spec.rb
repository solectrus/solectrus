describe BaseFee do
  before { Price.delete_all }

  # amount_per_kwh is required, but plays no role in the base fee
  def create_price(starts_at, amount_per_month = nil)
    Price.electricity.create!(
      starts_at: Date.parse(starts_at),
      amount_per_kwh: 0.30,
      amount_per_month:,
    )
  end

  def base_fee(string)
    described_class.for(Timeframe.new(string))
  end

  # The proration rule: one day carries the monthly amount divided by the length
  # of its month, so a full month adds up to exactly the monthly amount.
  describe '.for' do
    context 'without any electricity price' do
      it 'is zero' do
        expect(base_fee('2025-01')).to be_zero
      end
    end

    context 'without any base fee' do
      before { create_price('2024-01-01') }

      it 'is zero' do
        expect(base_fee('2025-01')).to be_zero
      end
    end

    context 'with a single base fee' do
      before { create_price('2024-01-01', 31) }

      it 'bills a full month as the monthly amount' do
        expect(base_fee('2025-01')).to be_within(0.001).of(31)
        expect(base_fee('2025-02')).to be_within(0.001).of(31)
      end

      it 'bills a full year as twelve monthly amounts' do
        expect(base_fee('2025')).to be_within(0.001).of(12 * 31)
      end

      it 'prorates a partial month by day' do
        expect(base_fee('2025-01-01..2025-01-10')).to be_within(0.001).of(10)
      end

      it 'is zero before the price starts' do
        expect(base_fee('2023')).to be_zero
      end
    end

    context 'with a base fee change' do
      before do
        create_price('2024-01-01', 31)
        create_price('2025-02-01', 62)
      end

      it 'uses the fee in force on each day' do
        expect(base_fee('2025-01-30..2025-02-02')).to be_within(0.001).of(
          (2 * 31 / 31.0) + (2 * 62 / 28.0),
        )
      end
    end

    # A record defines the complete tariff for its window, so a newer one
    # without a base fee cancels an older one that had one.
    context 'when a newer price has no base fee' do
      before do
        create_price('2024-01-01', 31)
        create_price('2025-02-01')
      end

      it 'bills nothing from that date on' do
        expect(base_fee('2025-01')).to be_within(0.001).of(31)
        expect(base_fee('2025-02')).to be_zero
      end
    end

    # The window is what carries the fee, not the day the timeframe is named
    # after: P4D is named after today and ends yesterday.
    context 'with a relative timeframe' do
      before { create_price('2024-01-01', 31) }

      it 'bills the days the window covers' do
        travel_to Time.zone.local(2025, 2, 3, 9, 0) do
          expect(base_fee('P4D')).to be_within(0.001).of(
            (2 * 31 / 31.0) + (2 * 31 / 28.0),
          )
        end
      end

      it 'ignores a fee that starts after the window' do
        travel_to Time.zone.local(2025, 2, 3, 9, 0) do
          create_price('2025-02-03', 310)

          expect(base_fee('P4D')).to be_within(0.001).of(
            (2 * 31 / 31.0) + (2 * 31 / 28.0),
          )
        end
      end
    end

    # A timeframe answered by InfluxDB starts and ends at an arbitrary time of
    # day, so a day it only touches counts by the fraction it covers - two
    # adjacent windows never bill the same day twice.
    context 'with an hourly timeframe' do
      before { create_price('2024-01-01', 31) }

      it 'counts a touched day by the fraction it covers' do
        travel_to Time.zone.local(2025, 2, 1, 12, 0) do
          expect(base_fee('P24H')).to be_within(0.001).of(
            (0.5 * 31 / 31.0) + (0.5 * 31 / 28.0),
          )
        end
      end

      # Timeframe.all has no window before the first measurement.
      it 'is zero for a timeframe without a beginning' do
        timeframe = Timeframe.new('all', min_date: nil)

        expect(described_class.for(timeframe)).to be_zero
        expect(described_class.per_hour(timeframe)).to be_zero
      end
    end
  end

  # The rate spreads the amount over the very window it was measured on, so the
  # points of a chart add up to the fee of the part they cover.
  describe '.per_hour' do
    before { create_price('2024-01-01', 31) }

    def per_hour(string)
      described_class.per_hour(Timeframe.new(string))
    end

    it 'is the amount divided by the hours of the window' do
      expect(per_hour('2025-01') * 31 * 24).to be_within(0.01).of(31)
    end

    # January bills 31/31 per day, February 2025 bills 31/28. A rate read off a
    # single date would apply one of the two to all four days.
    it 'weights each day of a window that crosses a month boundary' do
      expect(per_hour('2025-01-30..2025-02-02') * 4 * 24).to be_within(
        0.001,
      ).of((2 * 31 / 31.0) + (2 * 31 / 28.0))
    end

    it 'is zero without any base fee' do
      Price.delete_all
      create_price('2024-01-01')

      expect(per_hour('2025-01')).to be_zero
    end
  end

  # Asked by callers that split a value into fee and energy, before they build
  # the second half.
  describe '.any?' do
    it 'is false without any electricity price' do
      expect(described_class).not_to be_any
    end

    it 'is false for a tariff that has no base fee' do
      create_price('2024-01-01')

      expect(described_class).not_to be_any
    end

    it 'is true once a record carries a base fee' do
      create_price('2024-01-01', 12)

      expect(described_class).to be_any
    end

    # A record without an amount cancels an older one, but the history still
    # holds a fee, so the split stays meaningful for the older dates.
    it 'is true where only an older record carries a base fee' do
      create_price('2024-01-01', 12)
      create_price('2025-01-01')

      expect(described_class).to be_any
    end
  end
end
