describe DateInterval do
  subject { described_class.new(starts_at:, ends_at:) }

  before do
    Price.electricity.create! starts_at: Date.new(2021, 1, 1),
                              value: 0.20,
                              note: 'First price'

    Price.electricity.create! starts_at: Date.new(2022, 1, 1),
                              value: 0.30,
                              note: 'Second price'

    Price.electricity.create! starts_at: 2.months.since,
                              value: 0.40,
                              note: 'Future price'

    Price.feed_in.create! starts_at: Date.new(2021, 1, 1),
                          value: 0.08,
                          note: 'Second price'
  end

  describe '#price_sections' do
    subject { super().price_sections }

    context 'when completely before first year' do
      let(:starts_at) { Date.new(2020, 1, 1) }
      let(:ends_at) { Date.new(2020, 12, 31) }

      it 'returns blank sections' do
        is_expected.to eq([])
      end
    end

    context 'when partly in first year' do
      let(:starts_at) { Date.new(2020, 12, 1) }
      let(:ends_at) { Date.new(2021, 2, 1) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2021, 1, 1),
              ends_at: Date.new(2021, 2, 1),
              electricity: 0.20,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when one old price exits' do
      let(:starts_at) { Date.new(2020, 12, 1) }
      let(:ends_at) { Date.new(2021, 2, 1) }

      before do
        Price.electricity.create! starts_at: Date.new(2000, 1, 1),
                                  value: 0.10,
                                  note: 'Very old price'
      end

      it 'returns two sections with complete prices' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2020, 12, 1),
              ends_at: Date.new(2020, 12, 31).end_of_day,
              electricity: 0.10,
              feed_in: 0.0, # filled up!
            },
            {
              starts_at: Date.new(2021, 1, 1),
              ends_at: Date.new(2021, 2, 1),
              electricity: 0.20,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when first year' do
      let(:starts_at) { Date.new(2021, 1, 1) }
      let(:ends_at) { Date.new(2021, 12, 31) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2021, 1, 1),
              ends_at: Date.new(2021, 12, 31),
              electricity: 0.20,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when inside first year' do
      let(:starts_at) { Date.new(2021, 5, 1) }
      let(:ends_at) { Date.new(2021, 5, 31) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2021, 5, 1),
              ends_at: Date.new(2021, 5, 31),
              electricity: 0.20,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when overlapping first and second year' do
      let(:starts_at) { Date.new(2021, 11, 1) }
      let(:ends_at) { Date.new(2022, 2, 28) }

      it 'returns two sections' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2021, 11, 1),
              ends_at: Date.new(2021, 12, 31).end_of_day,
              electricity: 0.20,
              feed_in: 0.08,
            },
            {
              starts_at: Date.new(2022, 1, 1),
              ends_at: Date.new(2022, 2, 28),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when second year' do
      let(:starts_at) { Date.new(2022, 1, 1) }
      let(:ends_at) { Date.new(2022, 12, 31) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2022, 1, 1),
              ends_at: Date.new(2022, 12, 31),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when beginning of second year' do
      let(:starts_at) { Date.new(2022, 1, 1) }
      let(:ends_at) { Date.new(2022, 1, 31) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2022, 1, 1),
              ends_at: Date.new(2022, 1, 31),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when two years' do
      let(:starts_at) { Date.new(2021, 1, 1) }
      let(:ends_at) { Date.new(2022, 12, 31) }

      it 'returns two sections' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2021, 1, 1),
              ends_at: Date.new(2021, 12, 31).end_of_day,
              electricity: 0.20,
              feed_in: 0.08,
            },
            {
              starts_at: Date.new(2022, 1, 1),
              ends_at: Date.new(2022, 12, 31),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when overlapping second year' do
      let(:starts_at) { Date.new(2022, 11, 1) }
      let(:ends_at) { Date.new(2023, 12, 31) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2022, 11, 1),
              ends_at: Date.new(2023, 12, 31),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when after second year' do
      let(:starts_at) { Date.new(2023, 1, 1) }
      let(:ends_at) { Date.new(2023, 12, 31) }

      it 'returns one section' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2023, 1, 1),
              ends_at: Date.new(2023, 12, 31),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end

    context 'when from first year and without end date' do
      let(:starts_at) { Date.new(2020, 1, 1) }
      let(:ends_at) { nil }

      it 'returns two sections' do
        is_expected.to eq(
          [
            {
              starts_at: Date.new(2021, 1, 1),
              ends_at: Date.new(2021, 12, 31).end_of_day,
              electricity: 0.20,
              feed_in: 0.08,
            },
            {
              starts_at: Date.new(2022, 1, 1),
              electricity: 0.30,
              feed_in: 0.08,
            },
          ],
        )
      end
    end
  end
end
