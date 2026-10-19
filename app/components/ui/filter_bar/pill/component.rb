# A part of the filter in Ui::FilterBar: the content, with an optional icon
# before it. With `remove_path:`, a small x follows it, which removes this
# part from the filter (see Ui::RemoveLink).
class Ui::FilterBar::Pill::Component < ViewComponent::Base
  def initialize(icon: nil, remove_path: nil)
    super()
    @icon = icon
    @remove_path = remove_path
  end

  def call
    tag.span(class: 'inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-sm whitespace-nowrap bg-white dark:bg-gray-900 text-gray-700 dark:text-gray-200 ring-1 ring-inset ring-gray-200 dark:ring-gray-700') do
      safe_join(
        [
          (helpers.icon(@icon, class: 'text-xs text-gray-400 dark:text-gray-500') if @icon),
          content,
          (render Ui::RemoveLink::Component.new(href: @remove_path) if @remove_path),
        ].compact,
      )
    end
  end
end
