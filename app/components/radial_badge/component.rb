class RadialBadge::Component < ViewComponent::Base
  def initialize(percent: nil, title: nil, size: 6, neutral: false)
    if percent && (percent.negative? || percent > 100)
      raise ArgumentError, 'percent must be between 0 and 100'
    end

    super
    @percent = percent&.round
    @title = title
    @size = size
    @neutral = neutral || !percent
  end
  attr_reader :percent, :title, :size, :neutral

  def variant_class
    'percent' if percent
  end

  def border_color
    return 'border-slate-200' if neutral

    case percent
    when 0..33
      'border-red-200'
    when 34..66
      'border-orange-200'
    when 66..100
      'border-green-200'
    end
  end

  def background_color
    return 'sm:bg-slate-200' if neutral

    case percent
    when 0..33
      'sm:bg-red-200'
    when 34..66
      'sm:bg-orange-200'
    when 66..100
      'sm:bg-green-200'
    end
  end

  def text_color
    return 'text-slate-500' if neutral

    case percent
    when 0..33
      'text-red-600'
    when 34..66
      'text-orange-600'
    when 66..100
      'text-green-600'
    end
  end
end
