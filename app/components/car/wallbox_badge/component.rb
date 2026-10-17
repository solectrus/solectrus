# The plug of a car and the charging power next to it, in one badge, in the
# gauge and in the bar (see Car::RangeGauge::Component and
# Car::RangeBar::Component). With the plug alone, the badge is round.
class Car::WallboxBadge::Component < ViewComponent::Base
  include Car::BatteryDisplay

  # The classes of each size, and the width of a round badge. The gauge
  # scales its badge with the arc, and places it below the other items. The
  # bar keeps it as high as the badge of the place. The class names stay
  # literal, so Tailwind finds them.
  SIZES = {
    gauge: {
      base: 'gap-2 h-[clamp(2rem,9cqi,2.75rem)] mt-[clamp(0.75rem,5cqi,1.5rem)] first:mt-0 text-[clamp(0.875rem,4.5cqi,1.25rem)]',
      round: 'w-[clamp(2rem,9cqi,2.75rem)]',
    },
    bar: {
      base: 'gap-1.5 h-[clamp(1.75rem,7.5cqi,2.25rem)]',
      round: 'w-[clamp(1.75rem,7.5cqi,2.25rem)]',
    },
  }.freeze
  private_constant :SIZES

  # `state` holds the values of one car (see Car::Live::State). `size` is a
  # key of SIZES.
  def initialize(state:, size:)
    super()
    @state = state
    @size = SIZES[size]
  end

  attr_reader :state

  def badge_classes
    class_names(
      'flex items-center rounded-full bg-slate-100 dark:bg-slate-800',
      @size[:base],
      charging_power? ? 'px-[clamp(0.75rem,4cqi,1.25rem)] tabular-nums' : [@size[:round], 'justify-center'],
      Car::BatteryDisplay.charging_classes(charging?),
    )
  end
end
