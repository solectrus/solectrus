module SummaryHelper
  def create_summary(date:, updated_at: Time.current, values: [])
    Summary.where(date:).delete_all

    Summary.create!(date:, updated_at:)

    SummaryValue.insert_all!(
      values.map do |v|
        { date:, field: v.first, aggregation: v.second, value: v.third }
      end,
    )
  end
end

RSpec.configure { |config| config.include SummaryHelper }
