class Insights::BatteryFullDays < Insights::Base
  def call
    SummaryValue
      .where(field: :battery_soc, aggregation: :max)
      .where(value: 100)
      .where(
        date:
          timeframe.effective_beginning_date..timeframe.effective_ending_date,
      )
      .select(:date)
      .distinct
      .count
  end
end
