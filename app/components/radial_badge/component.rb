class RadialBadge::Component < ViewComponent::Base
  def initialize(percent: nil, title: nil, neutral: false)
    if percent && (percent.negative? || percent > 100)
      raise ArgumentError,
            "percent must be between 0 and 100, got #{percent.inspect}"
    end

    super()
    @percent = percent&.round
    @title = title
    @neutral = neutral || !percent
  end
  attr_reader :percent, :title, :neutral

  def variant_class
    'percent' if percent&.nonzero?
  end

  def border_color
    return 'border-slate-200 dark:border-slate-800' if neutral

    case percent
    when 0
      'border-transparent'
    when 1..33
      'border-red-200 dark:border-red-900'
    when 34..66
      'border-orange-200 dark:border-yellow-900'
    when 66..100
      'border-green-200 dark:border-green-900'
    end
  end

  def background_color
    return 'xl:tall:bg-slate-200 xl:tall:dark:bg-slate-800' if neutral

    case percent
    when 0..33
      'xl:tall:bg-red-200 dark:xl:tall:bg-red-900'
    when 34..66
      'xl:tall:bg-orange-200 dark:xl:tall:bg-yellow-900'
    when 66..100
      'xl:tall:bg-green-200 dark:xl:tall:bg-green-900'
    end
  end

  def text_color
    return 'text-slate-500 dark:text-slate-400' if neutral

    case percent
    when 0..33
      'text-red-600 dark:text-red-600 xl:tall:dark:text-inherit'
    when 34..66
      'text-orange-600 dark:text-orange-600 xl:tall:dark:text-inherit'
    when 66..100
      'text-green-600 dark:text-green-600 xl:tall:dark:text-inherit'
    end
  end
end
