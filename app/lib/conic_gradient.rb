# The CSS background of a ring of colored parts, as a conic gradient that
# starts at the top, like the ring of the overview of the car page and the
# ring of a charging session. The ring with gaps between its parts and a
# tooltip is DonutChart::Component.
module ConicGradient
  # `parts` are pairs of a CSS color and a share in percent
  def self.css(parts)
    start = 0
    stops = parts.map do |color, percent|
      stop = start + percent
      "#{color} #{start.round(2)}% #{stop.round(2)}%".tap { start = stop }
    end
    "conic-gradient(#{stops.join(', ')})"
  end
end
