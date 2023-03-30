class MinMaxBar::Component < ViewComponent::Base
  def initialize(minmax:, title:, color:, range:)
    super

    @minmax = minmax
    @title = title
    @color = color
    @range = range

    raise ArgumentError unless range
    raise ArgumentError if extent.zero?
    raise ArgumentError if minmax.nil? || minmax.first > minmax.last
    raise ArgumentError unless color.in?(%i[blue red])
  end
  attr_reader :minmax, :title, :color, :range

  def outer_class
    case color
    when :blue
      'bg-sky-200'
    when :red
      'bg-orange-200'
    end
  end

  def inner_class
    case color
    when :blue
      'bg-sky-400'
    when :red
      'bg-red-400'
    end
  end

  def text_class
    case color
    when :blue
      'text-sky-400'
    when :red
      'text-red-400'
    end
  end

  def width_in_percent
    ((minmax.second - minmax.first) * 100.0 / extent).round
  end

  def start_in_percent
    ((minmax.first - range.first) * 100 / extent).round
  end

  def extent
    range.size - 1
  end
end
