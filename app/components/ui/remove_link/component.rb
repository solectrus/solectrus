# The small x at the end of a pill of Ui::FilterBar that removes this part
# from the filter. `href:` is the address of the list without it.
class Ui::RemoveLink::Component < ViewComponent::Base
  CSS_CLASS =
    '-mr-1 inline-flex items-center rounded-full p-0.5 opacity-60 ' \
    'hover:opacity-100 focus-visible:opacity-100 hover:bg-black/5 dark:hover:bg-white/10'.freeze
  private_constant :CSS_CLASS

  def initialize(href:)
    super()
    @href = href
  end

  def call
    link_to @href, class: CSS_CLASS, data: { turbo_frame: '_top', controller: 'tooltip' }, title: t('.remove'), 'aria-label': t('.remove') do
      helpers.icon('xmark', class: 'text-[0.625rem]')
    end
  end
end
