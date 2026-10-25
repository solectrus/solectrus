# A button that opens a panel below it, like the menu of a Ui::Dropdown or a
# few controls that find no room on a phone. A click beside the panel and
# Escape close it again. With `pick: true` on the panel, a tap on a link or a
# button inside closes it too, like the pick of a menu entry.
#
# The trigger, the panel and the box around them take the classes and the
# attributes of the caller. The box needs `relative` or another position for
# the panel. The content of the block stands between the trigger and the
# panel, like a native select over the button that picks a link of the panel
# (see `choose` in the controller).
#
#   = render Ui::Popover::Component.new(class: 'relative') do |popover|
#     - popover.with_trigger(class: 'rounded-md p-2', 'aria-label': 'Options') do
#       = icon 'sliders'
#     - popover.with_panel(class: 'absolute right-0 mt-2 w-96') do
#       = render Options::Component.new
class Ui::Popover::Component < ViewComponent::Base
  CONTROLLER = 'ui--popover--component'.freeze
  private_constant :CONTROLLER

  # The panel grows a little as it fades in, from the corner below the
  # button
  TRANSITION = {
    transition_enter: 'transition ease-out duration-100',
    transition_enter_start: 'opacity-0 scale-95',
    transition_enter_end: 'opacity-100 scale-100',
    transition_leave: 'transition ease-in duration-75',
    transition_leave_start: 'opacity-100 scale-100',
    transition_leave_end: 'opacity-0 scale-95',
  }.freeze
  private_constant :TRANSITION

  renders_one :trigger,
              lambda { |data: {}, **options, &block|
                tag.button type: 'button',
                           'aria-haspopup': 'true',
                           'aria-expanded': 'false',
                           data: merge_data(data, ui__popover__component_target: 'button', action: "click->#{CONTROLLER}#toggle"),
                           **options,
                           &block
              }

  renders_one :panel,
              lambda { |pick: false, data: {}, **options, &block|
                tag.div class: ['hidden', options.delete(:class)],
                        data: merge_data(data, **TRANSITION, ui__popover__component_target: 'panel', action: ("click->#{CONTROLLER}#pick" if pick)),
                        **options,
                        &block
              }

  def initialize(data: {}, **options)
    super()
    @data = data
    @options = options
  end

  def call
    tag.div safe_join([trigger, content, panel]), data: merge_data(@data, controller: CONTROLLER), **@options
  end

  private

  # The controllers and the actions of the caller stay beside the own ones
  def merge_data(data, **own)
    data.merge(own.compact) do |key, theirs, ours|
      %i[controller action].include?(key) ? "#{ours} #{theirs}" : theirs
    end
  end
end
