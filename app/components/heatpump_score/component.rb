class HeatpumpScore::Component < ViewComponent::Base
  def initialize(score)
    if score < 1 || score > 5
      raise ArgumentError, "score must be between 1 and 5, got #{score.inspect}"
    end

    super
    @score = score
  end

  attr_reader :score

  def background_color(position)
    if position == score.round
      case position
      when 5
        'bg-red-400'
      when 4
        'bg-orange-400'
      when 3
        'bg-yellow-200'
      when 2
        'bg-emerald-400'
      when 1
        'bg-green-500'
      end
    else
      'bg-slate-500'
    end
  end

  def title
    "THOpMeter #{formatted_score}"
  end

  def formatted_score
    number_with_precision(
      score,
      precision: 1,
      separator: I18n.t('number.format.separator'),
    )
  end
end
