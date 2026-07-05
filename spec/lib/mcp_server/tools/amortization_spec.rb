describe McpServer::Tools::Amortization do
  include ActiveSupport::Testing::TimeHelpers

  before do
    travel_to Date.new(2024, 6, 15)
    Summary.delete_all
  end

  # One seeded day per month from 2023-07 to 2024-06 with 10 kWh each:
  # savings = 2.545 per month (prices seeded in rails_helper).
  def seed_steady_year
    12.times do |index|
      create_summary(
        date: Date.new(2023, 7, 10) + index.months,
        values: [
          [:house_power, :sum, 10_000],
          [:grid_import_power, :sum, 0],
          [:grid_export_power, :sum, 0],
        ],
      )
    end
  end

  def data_from(response)
    JSON.parse(response.content.first[:text], symbolize_names: true)
  end

  describe '.call' do
    context 'without any cash flows' do
      it 'reports that there is nothing to amortize' do
        response = described_class.call(server_context: nil)

        expect(response.error?).to be(false)
        data = data_from(response)
        expect(data[:available]).to be(false)
        expect(data[:message]).to include('No cash flows')
      end
    end

    context 'with measured savings and an investment' do
      before do
        seed_steady_year
        CashFlow.create!(date: Date.new(2023, 8, 1), amount: -50, note: 'PV')
      end

      it 'returns the key amortization figures' do
        response = described_class.call(server_context: nil)

        expect(response.error?).to be(false)
        data = data_from(response)

        aggregate_failures do
          expect(data[:currency]).to eq(Rails.configuration.x.currency)
          expect(data[:period_years]).to eq(Setting.amortization_period_years)
          expect(data[:installation_date]).to eq('2023-07-10')
          expect(data[:degree_percent]).to be_within(0.1).of(30.54 / 50 * 100)
          expect(data[:net_position]).to be_within(0.01).of(30.54 - 50)
          expect(data[:projection_uncertain]).to be(true)
          expect(data[:yearly_series].first).to include(
            year: 2023,
            projected: false,
          )
        end
      end

      it 'accepts what-if overrides and reflects them in the response' do
        base = data_from(described_class.call(server_context: nil))
        scenario =
          data_from(
            described_class.call(server_context: nil, interest_rate: 5.0),
          )

        aggregate_failures do
          expect(scenario[:interest_rate]).to eq(5.0)
          expect(scenario[:npv]).not_to eq(base[:npv])
        end
      end

      it 'clamps out-of-range overrides into the allowed bounds' do
        response =
          described_class.call(
            server_context: nil,
            period_years: 999,
            interest_rate: 99,
          )

        data = data_from(response)
        aggregate_failures do
          # Echoes the clamped values actually used, not the raw request.
          expect(data[:period_years]).to eq(
            AmortizationControls::Component::PERIOD_RANGE.max,
          )
          expect(data[:interest_rate]).to eq(10.0)
          expect(data[:profit_nominal]).to be_a(Numeric)
        end
      end
    end
  end
end
