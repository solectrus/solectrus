class SummaryUpdater
  def self.call
    new.call
  end

  def call
    SummaryValue.transaction do
      costs_count = create_missing_records(:grid_costs, :grid_import_power)
      revenue_count = create_missing_records(:grid_revenue, :grid_export_power)
      total_created = costs_count + revenue_count
      if total_created.positive?
        Rails.logger.info("Created #{total_created} missing summary values")
      end

      total_updated = update_all_fields
      if total_updated.positive?
        Rails.logger.info("Updated #{total_updated} summary values")
      end
    end
  end

  private

  def create_missing_records(financial_field, power_field)
    sql = <<~SQL.squish
      INSERT INTO summary_values(field, aggregation, value, date)
      SELECT ?, 'sum', 0, date
      FROM summary_values
      WHERE field = ?
      AND aggregation = 'sum'
      ON CONFLICT (date, aggregation, field) DO NOTHING
    SQL

    sanitized_sql =
      SummaryValue.sanitize_sql([sql, financial_field, power_field])
    SummaryValue.connection.execute(sanitized_sql).cmd_tuples
  end

  def update_all_fields
    sql = <<~SQL.squish
      WITH price_calculations AS (
        SELECT
          sv.date,
          sv.field,
          sv.value,
          CASE sv.field
            WHEN 'grid_import_power' THEN 'electricity'
            WHEN 'grid_export_power' THEN 'feed_in'
          END AS price_name,
          CASE sv.field
            WHEN 'grid_import_power' THEN 'grid_costs'::field_enum
            WHEN 'grid_export_power' THEN 'grid_revenue'::field_enum
          END AS target_field
        FROM summary_values sv
        WHERE sv.field IN ('grid_import_power', 'grid_export_power')
          AND sv.aggregation = 'sum'
          AND sv.value > 0
      ),
      price_lookup AS (
        SELECT
          pc.*, p.value AS price_value
        FROM price_calculations pc
        JOIN LATERAL (
          SELECT p.value
          FROM prices p
          WHERE p.name = pc.price_name
            AND p.starts_at <= pc.date
          ORDER BY p.starts_at DESC
          LIMIT 1
        ) p ON true
      )
      UPDATE summary_values
      SET value = pl.value * pl.price_value / 1000
      FROM price_lookup pl
      WHERE summary_values.date = pl.date
        AND summary_values.field = pl.target_field
        AND summary_values.aggregation = 'sum';
    SQL

    result = SummaryValue.connection.execute(sql)
    result.cmd_tuples
  end
end
