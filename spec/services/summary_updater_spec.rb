describe SummaryUpdater do
  let(:date) { Date.yesterday }

  before do
    create_summary(
      date:,
      values: [
        [:grid_import_power, :sum, 1000], # 1 kWh
        [:grid_export_power, :sum, 500], # 0.5 kWh
        [:grid_costs, :sum, 0], # Will be calculated
        [:grid_revenue, :sum, 0], # Will be calculated
      ],
    )
  end

  describe '.call' do
    subject(:call) { described_class.call }

    def summary_value(field)
      SummaryValue.find_by(date:, field:).value
    end

    it 'updates both grid_costs and grid_revenue summary values' do
      # Create initial prices - this will trigger callback and create cost values
      electricity_price =
        Price.create!(name: :electricity, starts_at: date - 2.days, value: 0.25)
      feed_in_price =
        Price.create!(name: :feed_in, starts_at: date - 2.days, value: 0.08)

      # Verify initial values were updated
      expect(summary_value(:grid_costs)).to eq(0.25)
      expect(summary_value(:grid_revenue)).to eq(0.04)

      # Update prices - this should trigger callback and update cost values
      electricity_price.update!(value: 0.30)
      feed_in_price.update!(value: 0.10)

      expect(summary_value(:grid_costs)).to eq(0.30) # 1000 * 0.30 / 1000 = 0.30
      expect(summary_value(:grid_revenue)).to eq(0.05) # 500 * 0.10 / 1000 = 0.05
    end

    context 'when no power data exists' do
      before do
        SummaryValue.where(
          field: %i[grid_import_power grid_export_power],
        ).delete_all
      end

      it 'does not crash but updates zero records' do
        expect { call }.not_to(
          change do
            SummaryValue.where(field: %i[grid_costs grid_revenue]).count
          end,
        )
      end
    end

    context 'when no existing cost summary values exist' do
      before do
        SummaryValue.where(field: %i[grid_costs grid_revenue]).delete_all
      end

      it 'creates missing financial records and calculates values' do
        # Create prices - this will trigger callback and create records with 0 values
        Price.create!(name: :electricity, starts_at: date - 2.days, value: 0.25)
        Price.create!(name: :feed_in, starts_at: date - 2.days, value: 0.08)

        # At this point records exist but with calculated values, not testing creation
        expect(
          SummaryValue.where(field: %i[grid_costs grid_revenue]).count,
        ).to eq(2)

        # Verify the calculated values
        expect(summary_value(:grid_costs)).to eq(0.25) # 1000 * 0.25 / 1000
        expect(summary_value(:grid_revenue)).to eq(0.04) # 500 * 0.08 / 1000
      end
    end
  end
end
