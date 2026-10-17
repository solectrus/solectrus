# The holder of a charging session in the list: the car in its color, a
# guest, or "not assigned", which is an open task and only an icon. With a car instead of a
# session, the badge shows that car, for example in the live view.
#
# A prominent badge stands on the card itself as a heading. It is larger, and
# in dark mode it needs more contrast than in a row of the list, whose hover
# color it must not match.
class Car::Badge::Component < ViewComponent::Base
  # A compact prominent badge has a smaller font at the same height, for the
  # name above the bar of the battery (see Car::RangeBar::Component)
  def initialize(charging_session: nil, car: nil, prominent: false, short: false, compact: false)
    super()
    @charging_session = charging_session
    @car = car || charging_session&.car
    @prominent = prominent
    @short = short
    @compact = compact
  end

  def prominent? = @prominent

  # A short badge names the car by its short name, and its title by the full
  # name
  def short? = @short

  attr_reader :charging_session, :car

  def state
    charging_session ? charging_session.state : :car
  end

  def label
    case state
    when :car then short? ? car.short_name : car.display_name
    when :guest then t('.guest')
    else t('.unassigned')
    end
  end

  def color
    car.display_color if state == :car
  end

  def title
    car.display_name if short? && state == :car
  end

  def css_class
    ['inline-flex items-center max-w-full rounded-full', size_class, color_class].join(' ')
  end

  private

  def size_class
    return 'gap-1.5 px-2 py-0.5 text-xs sm:text-sm' unless prominent?

    @compact ? 'gap-2 px-4 py-2 text-base' : 'gap-2 px-4 py-1.5 text-lg'
  end

  def color_class
    if prominent?
      'bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-100'
    else
      'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300'
    end
  end
end
