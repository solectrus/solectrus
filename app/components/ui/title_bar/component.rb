# The title bar of a page in a drill-down hierarchy on a phone: the
# title in the middle and, below the top level, a round back button to the
# parent page. The button carries no text, so the title keeps the middle on a
# narrow screen too. An action, like adding an entry, stands as a round icon
# button at the right, the counterpart of the back button. A form page has
# its save button there instead. From lg up the bar hides itself, the desktop
# names the page in its own way.
#
# A change between such pages slides (see component.css). The controller finds
# the direction: a page whose parent is the current page slides in from the
# right, the way back to the parent slides out to the right.
#
# A page can show a logo instead of the title, like the brand on a page at the
# top of the hierarchy. The title is then the text of the logo. `back_logo` is
# the logo of the parent, which the skeleton shows on the way back.
#
# `plain: true` keeps the background of the page. Without it, the page is the
# gray of a grouped list.
class Ui::TitleBar::Component < ViewComponent::Base
  # The data of a link to a page one level up or down, which slides there at
  # once and skips the hover prefetch (see the controller). `logo` is the logo
  # of that page, `plain` says that the page keeps its own background.
  def self.link_data(title, logo: nil, plain: false)
    { nav_title: title, nav_logo: logo, nav_plain: (true if plain), turbo_prefetch: false }.compact
  end

  renders_one :action,
              lambda { |href:, icon:, label:|
                link_to href,
                        class: 'ui-title-bar-action right-0 click-animation',
                        data: self.class.link_data(label),
                        title: label,
                        'aria-label': label do
                  icon(icon)
                end
              }

  # The save button of a form page: a check mark at the right.
  # It stands outside the form and names it by its id, `form`. The form-dirty
  # controller of the form enables it once a field changes, and it is the
  # button that Enter in a field takes (see Ui::SubmitButton::Component).
  renders_one :save,
              lambda { |form:, label: t('crud.save')|
                tag.button icon('check'),
                           type: :submit,
                           form:,
                           disabled: true,
                           class: 'ui-title-bar-action ui-title-bar-save right-0 click-animation',
                           title: label,
                           'aria-label': label,
                           data: { form_dirty_submit: true }
              }

  # `back_slide: false` for a parent without a title bar, like the car page:
  # the skeleton would show a title bar the parent does not have. The way
  # back is then a plain visit, as the way down from such a page.
  def initialize( # rubocop:disable Metrics/ParameterLists
    title:,
    logo: nil,
    back_href: nil,
    back_label: nil,
    back_logo: nil,
    back_slide: true,
    plain: false
  )
    super()
    @title = title
    @logo = logo
    @back_href = back_href
    @back_label = back_label
    @back_logo = back_logo
    @back_slide = back_slide
    @plain = plain
  end

  attr_reader :title, :logo, :back_href, :back_label, :plain

  def back_data
    @back_slide ? self.class.link_data(back_label, logo: @back_logo) : {}
  end

  # The controller compares paths, and the parent can carry a query, like the
  # filter of a list
  def parent_path
    URI.parse(back_href).path if back_href
  end

  # Turbo runs a page change as a view transition only when both pages ask for
  # it. Every page with a title bar does, so the slide stays between them.
  #
  # No preview from the cache on a tap: the controller slides to a skeleton at
  # once, and a preview would cut that slide short. The back gesture of the
  # browser still restores from the cache.
  def before_render
    helpers.content_for(
      :head,
      tag.meta(name: 'view-transition', content: 'same-origin'),
    )
    helpers.turbo_exempts_page_from_preview
  end
end
