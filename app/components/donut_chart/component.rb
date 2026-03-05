class DonutChart::Component < ViewComponent::Base
  renders_one :center
  renders_one :tooltip_footer

  ARC_STEP_DEGREES = 5.0
  private_constant :ARC_STEP_DEGREES

  GAP_DEGREES = 0.5
  private_constant :GAP_DEGREES

  GAP_COLOR = 'transparent'.freeze
  private_constant :GAP_COLOR

  DONUT_MASK = 'radial-gradient(circle, transparent 50%, black 50%)'.freeze
  private_constant :DONUT_MASK

  def initialize(segments: nil, url: nil, chart_url: nil, tooltip_placement: 'bottom')
    super()
    @segments = segments # [{percent:, color_var:, label:, sensor_name:}] or nil for placeholder
    @url = url
    @chart_url = chart_url
    @tooltip_placement = tooltip_placement
  end

  attr_reader :segments, :url, :chart_url, :tooltip_placement

  def placeholder?
    segments.blank?
  end

  def placeholder_style
    "-webkit-mask: #{DONUT_MASK}; mask: #{DONUT_MASK}"
  end

  def donut_style
    @donut_style ||= build_donut_style
  end

  # Build wedge-shaped clip-path polygons for each segment
  def segment_overlays
    @segment_overlays ||= build_segment_overlays
  end

  private

  def build_donut_style
    stops = []
    current = 0.0
    segments.each_with_index do |seg, i|
      pct = seg[:percent]
      seg_end = current + pct

      # Insert gap before each segment
      if i.positive?
        stops << "#{GAP_COLOR} #{current.round(2)}% #{(current + GAP_DEGREES).round(2)}%"
        current += GAP_DEGREES
      end

      stops << "var(#{seg[:color_var]}) #{current.round(2)}% #{seg_end.round(2)}%"
      current = seg_end
    end

    # Gap between last and first segment (closing the circle)
    if segments.size > 1
      gap_start = (100.0 - GAP_DEGREES).round(2)
      stops.unshift "#{GAP_COLOR} 0% #{GAP_DEGREES.round(2)}%"
      stops << "#{GAP_COLOR} #{gap_start}% 100%"
    end

    [
      "background: conic-gradient(from 0deg, #{stops.join(', ')})",
      "-webkit-mask: #{DONUT_MASK}",
      "mask: #{DONUT_MASK}",
    ].join('; ')
  end

  def build_segment_overlays
    current_angle = 0.0
    segments.map do |seg|
      start_angle = current_angle
      end_angle = current_angle + (seg[:percent] / 100.0 * 360.0)
      clip = wedge_clip_path(start_angle, end_angle)
      current_angle = end_angle
      seg.merge(clip_path: clip)
    end
  end

  # Generate a CSS clip-path polygon for a wedge from start_angle to end_angle (degrees)
  def wedge_clip_path(start_deg, end_deg)
    points = ['50% 50%'] # Center point
    angle = start_deg
    while angle < end_deg
      points << point_at(angle)
      angle += ARC_STEP_DEGREES
    end
    points << point_at(end_deg)
    "polygon(#{points.join(', ')})"
  end

  def point_at(degrees)
    rad = (degrees - 90) * Math::PI / 180.0 # -90 to start at top
    x = (Math.cos(rad) * 50) + 50
    y = (Math.sin(rad) * 50) + 50
    "#{x.round(2)}% #{y.round(2)}%"
  end
end
