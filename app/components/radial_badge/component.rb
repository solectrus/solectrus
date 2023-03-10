class RadialBadge::Component < ViewComponent::Base
  def initialize(percent: nil, title: nil, neutral: false)
    if percent && (percent.negative? || percent > 100)
      raise ArgumentError, 'percent must be between 0 and 100'
    end

    super
    @percent = percent&.round
    @title = title
    @neutral = neutral || !percent
  end
  attr_reader :percent, :title, :neutral

  def variant_class
    'percent' if percent&.nonzero?
  end

  def border_color
    return 'border-slate-200' if neutral

    case percent
    when 0
      'border-transparent'
    when 1..33
      'border-red-200'
    when 34..66
      'border-orange-200'
    when 66..100
      'border-green-200'
    end
  end

  def background_color
    return 'xl:bg-slate-200' if neutral

    case percent
    when 0..33
      'xl:bg-red-200'
    when 34..66
      'xl:bg-orange-200'
    when 66..100
      'xl:bg-green-200'
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
