class FluxQueryLogSubscriber < ActiveSupport::LogSubscriber
  attach_to :sensor_influx

  # An event without a query is a raw query (Influx::RawQuery): its program
  # can hold values of the data, so only its class and duration are logged.
  def query(event)
    return unless logger.debug?

    class_name = event.payload[:class]
    query_string = event.payload[:query]
    duration = event.duration.round

    line = "#{color(class_name, :magenta)} (#{duration}ms)"
    return debug(line) unless query_string

    sensors = event.payload[:sensors].join(',')
    colored_query = color(query_string, :yellow, { bold: true })

    # Colorize, indent query
    debug "#{line} sensors=#{sensors}\n  #{colored_query.gsub("\n", "\n  ")}"
  end
end
