module Summarizer
  def self.perform_later!(from: nil, to: nil)
    from = [from, Rails.configuration.x.installation_date].compact.max
    to = [to, Date.current].compact.min

    raise ArgumentError, 'from must be before to' if to < from

    # Fetch the records that need to be processed
    records_to_process = records_to_update(from:, to:)

    # Iterate over the records to process, but in reverse order, so that the
    # most recent records are processed first
    total_days = records_to_process.size
    records_to_process.reverse_each do |date|
      # Process the record for the given date
      SummarizerJob.perform_later(date)
    end

    # Return the number of processed days
    total_days
  end

  def self.records_to_update(from:, to:)
    # Find dates with existing summaries
    existing_dates = Summary.where(date: from..to).pluck(:date)

    # Find dates without a summary
    date_range = (from..to).to_a
    missing_dates = date_range - existing_dates

    # Find dates with an outdated summary
    outdated_dates = Summary.outdated.where(date: from..to).pluck(:date)

    # Combine both lists
    missing_dates + outdated_dates
  end
end
