class Insights::BatterySocLongestStreak < Insights::Base
  def call
    sql = <<~SQL.squish
      WITH good_days AS (
        SELECT DISTINCT date
        FROM summary_values
        WHERE field = 'battery_soc'
          AND aggregation = 'min'
          AND value > 0
          AND date >= $1
          AND date <= $2
      ),
      seq AS (
        SELECT
          date,
          date - (ROW_NUMBER() OVER (ORDER BY date))::int AS grp
        FROM good_days
      ),
      streaks AS (
        SELECT
          MIN(date) AS start_date,
          MAX(date) AS end_date,
          COUNT(*) AS streak_len
        FROM seq
        GROUP BY grp
      )
      SELECT
        start_date,
        end_date,
        streak_len
      FROM streaks
      ORDER BY streak_len DESC
      LIMIT 1
    SQL

    result =
      ActiveRecord::Base.connection.exec_query(
        sql,
        'battery_soc_longest_streak',
        [timeframe.effective_beginning_date, timeframe.effective_ending_date],
      )

    row = result.first

    if row
      {
        from: row['start_date'],
        to: row['end_date'],
        length: row['streak_len'],
      }
    else
      { from: nil, to: nil, length: 0 }
    end
  end
end
