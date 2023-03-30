# @label MinMaxBar Component
class MinMaxBarComponentPreview < ViewComponent::Preview
  # @!group Blue

  def blue_high
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [70, 100],
             color: :blue,
             range: 0..100,
           )
  end

  def blue_low
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [0, 30],
             color: :blue,
             range: 0..100,
           )
  end

  def blue_single
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [10, 10],
             color: :blue,
             range: 0..100,
           )
  end

  def blue_small
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [60, 63],
             color: :blue,
             range: 0..100,
           )
  end

  def blue_max
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [100, 100],
             color: :blue,
             range: 0..100,
           )
  end

  def blue_min
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [0, 0],
             color: :blue,
             range: 0..100,
           )
  end

  def blue_full
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [0, 100],
             color: :blue,
             range: 0..100,
           )
  end

  # @!endgroup

  # @!group Red

  def red_high
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [30, 40],
             color: :red,
             range: 5..40,
           )
  end

  def red_low
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [5, 8],
             color: :red,
             range: 5..40,
           )
  end

  def red_single
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [30, 30],
             color: :red,
             range: 5..40,
           )
  end

  def red_small
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [30, 31],
             color: :red,
             range: 5..40,
           )
  end

  def red_max
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [40, 40],
             color: :red,
             range: 5..40,
           )
  end

  def red_min
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [5, 5],
             color: :red,
             range: 5..40,
           )
  end

  def red_full
    render MinMaxBar::Component.new(
             title: 'title',
             minmax: [5, 40],
             color: :red,
             range: 5..40,
           )
  end

  # @!endgroup
end
