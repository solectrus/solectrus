class FluxQueryLogSubscriber < ActiveSupport::LogSubscriber
  attach_to :flux_reader

  def query(event)
    class_name = event.payload[:class]
    query_string = event.payload[:query]
    duration = (event.payload[:duration] * 1000).round

    colored_class = color(class_name, :magenta)
    colored_query = color(query_string, :yellow, { bold: true })

    # Colorize, indent query
    debug "#{colored_class} (#{duration}ms)\n  #{colored_query.gsub("\n", "\n  ")}"
  end
end
