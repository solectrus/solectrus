describe AmortizationCalculator do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Date.new(2024, 6, 15)

    # Runs transactional, so this does not affect the suite-wide seed data
    # created for system tests (which may exist when suites run together)
    Summary.delete_all
  end

  # Seeds one day with measured data. With grid import/export = 0 the savings
  # equal house consumption paid at the electricity price:
  #   savings = house_kwh * 0.2545 (prices seeded in rails_helper)
  def seed_savings_day(date, house_power_wh)
    create_summary(
      date:,
      values: [
        [:house_power, :sum, house_power_wh],
        [:grid_import_power, :sum, 0],
        [:grid_export_power, :sum, 0],
      ],
    )
  end

  # One seeded day per month from 2023-07 to 2024-06 with 10 kWh each:
  # savings = 2.545 per month, 30.54 in total, 342 days of data.
  def seed_steady_year(house_power_wh = 10_000)
    12.times do |index|
      seed_savings_day(Date.new(2023, 7, 10) + index.months, house_power_wh)
    end
  end

  # 12 months x 2.545 (see seed_steady_year)
  def total_savings
    30.54
  end

  def create_investment(amount: -50, date: Date.new(2023, 8, 1), note: 'PV')
    CashFlow.create!(date:, amount:, note:)
  end

  def result(interest_rate: 0.0, period_years: 20)
    described_class.new(period_years:, interest_rate:).result
  end

  describe 'savings measurement' do
    before do
      seed_steady_year
      create_investment
    end

    it 'clamps the start to the first summary date (ENV fallback guard)' do
      # 342 days from 2023-07-10 to 2024-06-15, not 1628 days since 2020-01-01
      aggregate_failures do
        expect(result.installation_date).to eq(Date.new(2023, 7, 10))
        expect(result.savings_per_day).to be_within(0.001).of(
          total_savings / 342,
        )
      end
    end

    it 'flags the prognosis as uncertain with less than a year of data' do
      expect(result.projection_uncertain).to be true
    end

    it 'echoes the parameters it was computed with' do
      r = result(period_years: 25, interest_rate: 4.5)

      aggregate_failures do
        expect(r.period_years).to eq(25)
        expect(r.interest_rate).to eq(4.5)
      end
    end
  end

  describe 'amortization degree' do
    before { seed_steady_year }

    it 'calculates the ratio of credits to debits (without interest)' do
      create_investment(amount: -50)

      expect(result.degree_percent).to be_within(0.01).of(
        total_savings / 50 * 100,
      )
    end

    it 'exceeds 100 percent uncapped when amortized' do
      create_investment(amount: -10)

      aggregate_failures do
        expect(result.degree_percent).to be_within(0.1).of(305.4)
        expect(result).to be_amortized
      end
    end

    it 'is nil without any debits' do
      create_investment(amount: 50, note: 'Revenue only')

      aggregate_failures do
        expect(result.degree_percent).to be_nil
        expect(result.prognosis?).to be false
      end
    end
  end

  describe 'cash flow categories' do
    before { seed_steady_year }

    it 'treats a subsidy as an investment reduction, not operating payback' do
      create_investment(amount: -100)
      CashFlow.create!(
        date: Date.new(2023, 8, 1), amount: 40, note: 'Grant', category: :subsidy,
      )

      r = result

      aggregate_failures do
        expect(r.gross_investment).to be_within(0.01).of(100)
        expect(r.investment_reduction).to be_within(0.01).of(40)
        expect(r.net_investment).to be_within(0.01).of(60)
        expect(r.operating_cashflow).to be_within(0.01).of(total_savings)
        # operating cash flow / net investment - the subsidy lowers the base
        # instead of inflating the numerator (which would give ~70 %).
        expect(r.degree_percent).to be_within(0.01).of(total_savings / 60 * 100)
      end
    end

    it 'subtracts operating costs and repairs from the operating cash flow' do
      create_investment(amount: -100)
      CashFlow.create!(
        date: Date.new(2023, 9, 1), amount: -5, note: 'Fee', category: :operating_cost,
      )
      CashFlow.create!(
        date: Date.new(2023, 10, 1), amount: -3, note: 'Fix', category: :repair,
      )

      r = result

      aggregate_failures do
        expect(r.net_investment).to be_within(0.01).of(100)
        expect(r.operating_cashflow).to be_within(0.01).of(total_savings - 8)
        expect(r.degree_percent).to be_within(0.01).of((total_savings - 8) / 100 * 100)
      end
    end

    it 'adds compensation to the operating cash flow' do
      create_investment(amount: -100)
      CashFlow.create!(
        date: Date.new(2023, 9, 1), amount: 10, note: 'Payout', category: :compensation,
      )

      expect(result.operating_cashflow).to be_within(0.01).of(total_savings + 10)
    end

    it 'ignores the neutral category in the investment and operating figures' do
      create_investment(amount: -100)
      CashFlow.create!(
        date: Date.new(2023, 9, 1), amount: 20, note: 'Misc', category: :other,
      )

      r = result

      aggregate_failures do
        expect(r.net_investment).to be_within(0.01).of(100)
        expect(r.operating_cashflow).to be_within(0.01).of(total_savings)
      end
    end
  end

  describe 'net position' do
    before { seed_steady_year }

    it 'equals savings minus investment without interest' do
      create_investment(amount: -50)

      expect(result.net_position).to be_within(0.01).of(total_savings - 50)
    end
  end

  describe 'future-dated cash flows' do
    before do
      seed_steady_year
      create_investment(amount: -50)
    end

    it 'excludes them from degree and net position' do
      base = result

      CashFlow.create!(date: Date.new(2024, 12, 1), amount: 1000, note: 'Future')
      with_future = result

      aggregate_failures do
        expect(with_future.degree_percent).to eq(base.degree_percent)
        expect(with_future.net_position).to eq(base.net_position)
      end
    end

    it 'includes them in break-even and profit' do
      base = result

      CashFlow.create!(date: Date.new(2024, 12, 1), amount: 1000, note: 'Future')
      with_future = result

      aggregate_failures do
        expect(with_future.profit_nominal).to be_within(0.01).of(
          base.profit_nominal + 1000,
        )
        expect(with_future.break_even_date).to be < base.break_even_date
      end
    end
  end

  describe 'cash flow date accuracy' do
    before do
      seed_steady_year
      create_investment(amount: -50)
    end

    it 'books a cash flow into the year of its date, not earlier' do
      baseline = result.yearly_series.index_by { |entry| entry[:year] }

      CashFlow.create!(date: Date.new(2030, 3, 10), amount: 500, note: 'Grant')
      with_grant = result.yearly_series.index_by { |entry| entry[:year] }

      aggregate_failures do
        # The year before the grant date is untouched...
        expect(with_grant[2029][:nominal]).to be_within(0.01).of(
          baseline[2029][:nominal],
        )
        # ...its own year and every later year are lifted by exactly the amount.
        expect(with_grant[2030][:nominal]).to be_within(0.01).of(
          baseline[2030][:nominal] + 500,
        )
        expect(with_grant[2031][:nominal]).to be_within(0.01).of(
          baseline[2031][:nominal] + 500,
        )
      end
    end

    it 'discounts a flow by the months between its date and the start' do
      # Two identical investments, one a year later: at r > 0 the later one is
      # discounted less towards the start, so it raises the NPV.
      early = result(interest_rate: 4.0).npv

      CashFlow.delete_all
      create_investment(amount: -50, date: Date.new(2024, 8, 1))
      late = result(interest_rate: 4.0).npv

      expect(late).to be > early
    end
  end

  describe 'cash flow before installation' do
    before { seed_steady_year }

    it 'moves the simulation start and keeps the entry' do
      create_investment(amount: -50, date: Date.new(2023, 1, 5))

      aggregate_failures do
        expect(result.yearly_series.first[:year]).to eq(2023)
        expect(result.degree_percent).to be_within(0.01).of(
          total_savings / 50 * 100,
        )
        expect(result.net_position).to be_within(0.01).of(total_savings - 50)
      end
    end
  end

  describe 'break-even without a negative balance' do
    before { seed_steady_year }

    it 'reports the first month when the balance is never negative' do
      # A tiny debit that the already-accrued savings cover from the start:
      # the cumulative balance never dips below zero, so the system counts
      # as amortized from the simulation start.
      create_investment(amount: -1, date: Date.new(2024, 6, 1))

      expect(result.break_even_date).to eq(Date.new(2023, 7, 1))
    end
  end

  describe 'yearly series' do
    before do
      seed_steady_year
      create_investment(amount: -50)
    end

    it 'flags past years as measured and future years as projected' do
      by_year = result.yearly_series.index_by { |entry| entry[:year] }

      aggregate_failures do
        # travel_to 2024-06-15, installation 2023-07: the start anchor (2023) is
        # in the past. PV year 1 ends 2024-07-09 - still ahead of today - so its
        # birthday (2024) already counts as projected, like every later one.
        # Day-accurate, matching the table (the birthdays come from it).
        expect(by_year[2023][:projected]).to be false
        expect(by_year[2024][:projected]).to be true
        expect(by_year[2025][:projected]).to be true
      end
    end

    it 'plots the same day-accurate balances as the table' do
      res = result
      series = res.yearly_series
      table = res.yearly_table

      # The chart's birthday points ARE the table rows (after the leading start
      # anchor), so the two views can never diverge - the last chart point
      # equals the table's last nominal balance.
      birthdays = series.drop(1)

      aggregate_failures do
        expect(birthdays.pluck(:nominal)).to eq(table.pluck(:nominal))
        expect(series.last[:year]).to eq(table.last[:period].end.year)
      end
    end
  end

  describe 'yearly table (day-accurate)' do
    before do
      seed_steady_year
      create_investment(amount: -50, date: Date.new(2023, 8, 1))
    end

    it 'anchors PV years on the exact installation date, not the calendar year' do
      table = result.yearly_table

      aggregate_failures do
        # The table starts at PV year 1 (no empty year-0 row); year 1 starts
        # exactly on the installation date (2023-07-10) - not Jan 1, not a month
        # boundary - and runs a full year; year 2 picks up the next day.
        expect(table.size).to eq(20) # period_years default
        expect(table[0][:period].begin).to eq(Date.new(2023, 7, 10))
        expect(table[0][:period].end).to eq(Date.new(2024, 7, 9))
        expect(table[1][:period].begin).to eq(Date.new(2024, 7, 10))
      end
    end

    it 'splits each PV year into savings and per-category flows that reconcile' do
      table = result.yearly_table

      aggregate_failures do
        # rounded savings plus all (rounded) category flows of a row equals its
        # balance change since the previous row (year 1 is measured against
        # zero) - the whole-euro basis makes the columns foot exactly.
        previous = 0
        table.each do |row|
          total = row[:savings].round + row[:flows].values.sum
          expect(total).to eq(row[:nominal] - previous)
          previous = row[:nominal]
        end

        # The -50 investment (Aug 2023) sits in PV year 1 as an 'investment'
        # flow; the sensor savings are reported separately, not inside flows.
        expect(table[0][:flows]['investment']).to be_within(0.01).of(-50)
        expect(table[0][:savings]).to be_positive
      end
    end

    it 'discounts the day-accurate balance, matching nominal exactly at 0%' do
      table = result(interest_rate: 0.0).yearly_table

      aggregate_failures do
        expect(table).to all(include(:npv))
        # No discounting at 0 %, so the discounted balance IS the nominal
        # balance - both columns are the same day-accurate figure, row for row.
        table.each { |row| expect(row[:npv]).to be_within(0.01).of(row[:nominal]) }
      end
    end

    it 'ties the discounted column to the npv KPI and trails nominal at r > 0' do
      res = result(interest_rate: 6.0)
      table = res.yearly_table

      aggregate_failures do
        # The discounted column IS the running Kapitalwert, so its last row
        # equals the headline npv exactly - the table and the KPI can't
        # contradict each other (the sign-flip we saw is gone).
        expect(table.last[:npv]).to be_within(0.01).of(res.npv)
        # Savings are discounted, so the discounted balance trails nominal.
        expect(table.last[:npv]).to be < table.last[:nominal]
      end
    end

    it 'lowers the discounted balance as the rate rises' do
      # The whole point of the column: unlike the nominal balance, it reacts to
      # the rate. A profitable system's later balance shrinks as the rate rises.
      low = result(interest_rate: 0.0).yearly_table.last[:npv]
      high = result(interest_rate: 6.0).yearly_table.last[:npv]

      expect(high).to be < low
    end

    it 'keeps the projected savings constant across future years' do
      res = result
      table = res.yearly_table

      # Every PV year lying entirely in the future is a pure projection, so it
      # must show the same expected savings. A leap year (366 days, e.g. PV year
      # 5 spanning 29 Feb 2028) must not add a day's worth over a 365-day year.
      future = table.select { |row| row[:period].begin > Date.new(2024, 6, 15) }

      aggregate_failures do
        expect(future.size).to eq(19) # years 2..20; year 1 straddles today
        future.each do |row|
          expect(row[:savings]).to be_within(0.01).of(res.savings_per_year)
        end
      end
    end

    it 'folds a pre-installation down payment into the first PV year' do
      # A deposit paid before the operating start has no year-0 row to live in
      # any more, so it must surface in year 1 rather than vanish.
      CashFlow.create!(date: Date.new(2023, 1, 5), amount: -200, note: 'Deposit')

      table = result.yearly_table

      expect(table[0][:flows]['investment']).to be_within(0.01).of(-250)
    end
  end

  describe 'operating period length' do
    it 'yields the start anchor plus exactly period_years birthdays' do
      seed_savings_day(Date.new(2023, 1, 10), 10_000)
      create_investment(amount: -50, date: Date.new(2023, 1, 1))

      years = result(period_years: 1).yearly_series.pluck(:year)

      # A one-year period commissioned in Jan 2023: the start anchor (2023) plus
      # the single birthday one year on. No extra birthday from an off-by-one
      # period end.
      expect(years).to eq([2023, 2024])
    end
  end

  describe 'yearly amortization degree' do
    before { seed_steady_year }

    it 'reports the cumulative degree (credits / debits) per year' do
      create_investment(amount: -50, date: Date.new(2023, 7, 1))
      by_year = result.yearly_series.index_by { |entry| entry[:year] }

      # Start anchor (Jul 2023): one measured month of savings against the 50
      # debit - the same credits / debits ratio as degree_percent, per PV year.
      expect(by_year[2023][:degree]).to be_within(0.01).of(2.545 / 50 * 100)
    end

    it 'is nil for years before the first debit' do
      create_investment(amount: -50, date: Date.new(2024, 2, 1))
      by_year = result.yearly_series.index_by { |entry| entry[:year] }

      expect(by_year[2023][:degree]).to be_nil
    end
  end

  describe 'net present value' do
    before do
      seed_steady_year
      create_investment(amount: -50)
    end

    it 'equals the nominal surplus for r = 0' do
      r = result(interest_rate: 0.0)

      expect(r.npv).to be_within(0.01).of(r.profit_nominal)
    end

    it 'is lower than the nominal surplus for r > 0' do
      r = result(interest_rate: 3.0)

      expect(r.npv).to be < r.profit_nominal
    end
  end

  describe 'internal rate of return' do
    it 'returns the rate at which the NPV is zero' do
      seed_steady_year
      create_investment(amount: -300)

      irr = result.irr_percent
      npv_at_irr = result(interest_rate: irr).npv

      expect(npv_at_irr.abs).to be < 1
    end

    it 'is nil without any inflows' do
      create_investment

      expect(result.irr_percent).to be_nil
    end
  end

  describe 'required annual savings' do
    before { seed_steady_year }

    it 'spreads the net investment evenly over the period for r = 0' do
      create_investment(amount: -50)

      expect(result.required_annual_savings).to be_within(0.01).of(2.5)
    end

    it 'is nil without a net investment' do
      create_investment(amount: 50, note: 'Revenue only')

      expect(result.required_annual_savings).to be_nil
    end
  end

  describe 'textbook validation example' do
    # 17,000 investment, ~1,900 annual benefit, 20 years, 5 % discount rate.
    # Expected from the standard year-end formulas: nominal amortization
    # ~8.9 years, NPV ~+6,700, IRR ~9.4 %, minimum annual benefit ~1,364,
    # nominal surplus ~21,000. Day-accurate flows and mid-year savings shift NPV
    # and IRR slightly and lower the required benefit to ~1,331 (savings, and so
    # the break-even annuity, are discounted only half a year, not a full one).
    before do
      # 622,135 Wh per month = 158.33 savings = 1,900 per year. 13 months
      # so that a full measured year exists and the rolling-year projection
      # (1,900) applies instead of the uncertain-data fallback.
      13.times do |index|
        seed_savings_day(Date.new(2023, 6, 10) + index.months, 622_135)
      end
      create_investment(amount: -17_000, date: Date.new(2023, 6, 1))
    end

    it 'reproduces the expected key figures' do
      r = result(interest_rate: 5.0)

      aggregate_failures do
        expect(r.profit_nominal).to be_within(800).of(21_000)
        expect(r.npv).to be_between(6_400, 7_700)
        expect(r.irr_percent).to be_between(9.0, 11.0)
        expect(r.required_annual_savings).to be_within(10).of(1_331)
        expect(r.break_even_date.year).to eq(2032)
      end
    end
  end

  describe 'month-accurate seasonality' do
    it 'reaches break-even earlier when savings come early' do
      # Same total savings, but all in the first vs. the last month
      seed_savings_day(Date.new(2023, 7, 10), 120_000)
      create_investment(amount: -25, date: Date.new(2023, 7, 1))
      result_early_savings = result

      Summary.delete_all
      CashFlow.delete_all

      seed_savings_day(Date.new(2024, 6, 10), 120_000)
      create_investment(amount: -25, date: Date.new(2023, 7, 1))
      result_late_savings = result

      expect(result_early_savings.break_even_date).to be <
        result_late_savings.break_even_date
    end
  end

  describe 'projection rate' do
    it 'uses only the rolling year when a full year of data exists' do
      # Older months with four times the savings must not affect the rate
      11.times do |index|
        seed_savings_day(Date.new(2022, 8, 10) + index.months, 40_000)
      end
      seed_steady_year
      create_investment

      r = result

      aggregate_failures do
        expect(r.projection_uncertain).to be false
        expect(r.savings_per_year).to be_within(0.01).of(total_savings)
        # per-day figure shares the rolling-year basis, not the all-time
        # average (which the 4x older months would inflate)
        expect(r.savings_per_day).to be_within(0.01).of(total_savings / 365)
      end
    end

    it 'loads measured savings with grouped queries, one per resolution' do
      13.times do |index|
        seed_savings_day(Date.new(2023, 6, 10) + index.months, 10_000)
      end
      create_investment

      allow(Sensor::Query::Total).to receive(:new).and_call_original

      result

      # Three grouped queries, each issued once: monthly savings (balance
      # series), the rolling year (projection rate, full year of data here) and
      # daily savings (the day-accurate table). None fan out per month or year.
      expect(Sensor::Query::Total).to have_received(:new).exactly(3).times
    end
  end

  describe 'caching' do
    # The :with_cache shared context does not take effect reliably here, so
    # stub the cache store explicitly.
    let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }

    before do
      allow(Rails).to receive(:cache).and_return(memory_store)
      Rails.cache.clear

      seed_steady_year
      create_investment(amount: -50)
    end

    it 'serves the class-level result from cache until an input changes' do
      allow(Sensor::Query::Total).to receive(:new).and_call_original

      # With less than a full year of data the rolling-year query is skipped, so
      # one computation issues two savings queries (monthly + daily). The second
      # call must hit the cache and query nothing.
      described_class.result
      described_class.result
      expect(Sensor::Query::Total).to have_received(:new).twice

      # Editing the register changes the key, so the next call recomputes.
      CashFlow.create!(date: Date.new(2024, 1, 15), amount: -10, note: 'Extra')
      described_class.result
      expect(Sensor::Query::Total).to have_received(:new).exactly(4).times
    end

    it 'recomputes when a parameter changes' do
      first = described_class.result

      second = described_class.result(interest_rate: 5.0)

      expect(second.npv).not_to eq(first.npv)
    end

    it 'discards a cached result with incompatible struct members' do
      # A Result serialized by an older app version raises TypeError on
      # deserialization (e.g. a renamed struct member). The stale entry must be
      # dropped and recomputed instead of bubbling up as a 500.
      first_read = true
      allow(Rails.cache).to receive(:fetch).and_wrap_original do |original, *args, &block|
        if first_read
          first_read = false
          raise TypeError, 'struct not compatible (:commissioning_date for :installation_date)'
        end
        original.call(*args, &block)
      end

      expect { described_class.result }.not_to raise_error
      expect(described_class.result).to be_a(described_class::Result)
    end
  end

  describe 'guards' do
    it 'returns no prognosis without any measured savings' do
      create_investment

      r = result

      aggregate_failures do
        expect(r.prognosis?).to be false
        expect(r.degree_percent).to be_nil
        expect(r.savings_per_day).to be_nil
        expect(r.savings_per_year).to be_nil
        expect(r.break_even_date).to be_nil
      end
    end

    it 'returns nil break-even when never amortized within the period' do
      seed_steady_year
      create_investment(amount: -1_000_000)

      expect(result.break_even_date).to be_nil
    end

    it 'handles a single day of measured data (installation today)' do
      # Only today has measured savings, so installation == today. A
      # same-day range would be rejected by Timeframe; the calculation must
      # still succeed instead of raising.
      seed_savings_day(Date.new(2024, 6, 15), 10_000)
      create_investment

      r = nil
      expect { r = result }.not_to raise_error

      aggregate_failures do
        expect(r.installation_date).to eq(Date.new(2024, 6, 15))
        expect(r.savings_per_day).to be_within(0.01).of(2.545)
        expect(r.prognosis?).to be true
      end
    end
  end
end
