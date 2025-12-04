class UpdateCheck::NotificationImporter
  def initialize(notifications_data)
    @notifications_data = notifications_data || []
  end

  attr_reader :notifications_data

  def call
    return if notifications_data.empty?

    records = build_records
    return if records.empty?

    Notification.upsert_all(records, unique_by: :id)
  rescue ActiveRecord::ActiveRecordError => e
    Rails.logger.warn("Failed to import notifications: #{e.message}")
  end

  private

  def build_records
    now = Time.current

    notifications_data.filter_map do |data|
      published_at = parse_datetime(data[:published_at])

      unless valid_data?(data, published_at)
        Rails.logger.warn("Skipping invalid notification data: #{data.inspect}")
        next
      end

      {
        id: data[:id],
        title: data[:title],
        body: data[:body],
        published_at:,
        created_at: now,
        updated_at: now,
      }
    end
  end

  def valid_data?(data, published_at)
    data[:id].present? && data[:title].present? && data[:body].present? &&
      published_at.present?
  end

  def parse_datetime(value)
    return if value.blank?

    Time.zone.parse(value)
  rescue ArgumentError
    nil
  end
end
