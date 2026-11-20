# The bar of a change on a track around zero, in the trend overview
# (TrendOverview::Change::Component) and for the months below it
# (Insights::Comparison::Component). Half the track to each side is the way
# from zero to `scale`. A change beyond the scale runs to the edge with a
# break in the bar. The color shows better or worse, gray a change that is
# neither, and a dot no change worth a bar (`rating: :same`). Without a
# change, the track stays empty. `data` are attributes of the track, like
# the anchor of a tooltip, which then points to the zero in its middle.
class TrendOverview::Bar::Component < ViewComponent::Base
  CLASSES = {
    better: 'bg-signal-positive',
    worse: 'bg-signal-negative',
    neutral: 'bg-slate-400/70',
  }.freeze
  private_constant :CLASSES

  def initialize(change:, rating:, scale:, data: {})
    super()
    @change = change
    @rating = rating
    @scale = scale
    @data = data
  end

  attr_reader :change, :rating, :data

  def bar? = change && rating != :same && @scale.positive?

  def broken? = change.abs > @scale

  def bar_style
    "width: #{(change.abs.clamp(0, @scale) * 50.0 / @scale).round(2)}%"
  end

  def bar_class
    ['trend-overview-bar', change.positive? ? 'is-up' : 'is-down', CLASSES[rating]]
  end
end
