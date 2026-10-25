# A page in a high sheet of a phone, over the page it belongs to: a list, or
# the form of one of its entries (see SheetPage). The sheet stays while its
# page changes in the frame inside it. Each page has a head with its title,
# the way back to the list, and an action at the right, like the button for
# a new entry or the save button of a form. The head stays at the top while
# the page scrolls, and a drag on it moves the sheet. A page one level down,
# with a way back, slides in from the right (see component_controller.ts).
#
# With `frame: false`, the sheet holds this one page, like the form of an
# entry of the list on the page below (see FormPageHelper#form_sheet?). Its
# form submits within the modal frame, so a save closes the sheet.
#
#   = render Ui::SheetPage::Component.new(title: 'Edit', back_href: list_path, back_label: 'Charging') do |page|
#     - page.with_save(form: form_page_id(record))
#     = render 'form', record:
class Ui::SheetPage::Component < ViewComponent::Base
  # A link at the right of the head, like the button for a new entry or the
  # map, which loads into its `frame`. The last one stands at the very right,
  # so it comes as the main action.
  renders_many :actions,
              lambda { |href:, icon:, label:, frame: nil|
                link_to icon(icon), href, class: BUTTON_CLASS, title: label, 'aria-label': label, data: { turbo_frame: frame }
              }

  # The save button of a form, which the form-dirty controller enables
  renders_one :save,
              lambda { |form:, label: t('ui.save')|
                tag.button icon('check'), type: :submit, form:, disabled: true, class: SAVE_CLASS, title: label, 'aria-label': label, data: { form_dirty_submit: true }
              }

  # Round buttons without text, as in Ui::TitleBar::Component, so the title
  # keeps the middle
  BUTTON_CLASS = 'flex size-9 items-center justify-center rounded-full bg-fill text-indigo-600 dark:text-indigo-400 click-animation focus-ring'.freeze
  SAVE_CLASS = 'flex size-9 items-center justify-center rounded-full bg-indigo-600 text-white disabled:opacity-40 click-animation focus-ring'.freeze
  WRAPPER_CLASS = 'flex-1 flex flex-col'.freeze
  private_constant :BUTTON_CLASS, :SAVE_CLASS, :WRAPPER_CLASS

  def initialize(title:, subtitle: nil, back_href: nil, back_label: nil, frame: true)
    super()
    @frame = frame
    @title = title
    @subtitle = subtitle
    @back_href = back_href
    @back_label = back_label
  end

  attr_reader :title, :subtitle, :back_href, :back_label

  # Two buttons at the right take the room of two on the left too, so the
  # title keeps the middle. The class names stay literal, so Tailwind finds
  # them.
  def head_columns
    actions.many? && !save? ? 'grid-cols-[5rem_1fr_5rem]' : 'grid-cols-[2.25rem_1fr_2.25rem]'
  end

  # The frame in which the pages of the sheet change, or a plain box for the
  # one page of a sheet without a frame
  def wrapper(&)
    return tag.div(class: WRAPPER_CLASS, &) unless @frame

    tag.turbo_frame(id: SheetPage::FRAME, class: WRAPPER_CLASS, data: frame_data, &)
  end

  # The controller asks in Ui::ConfirmDialog::Component before a link leaves
  # a form with unsaved changes
  def frame_data
    {
      controller: 'ui--sheet-page--component',
      ui__sheet_page__component_ui__confirm_dialog__component_outlet: Ui::ConfirmDialog::Component::SELECTOR,
      action: 'turbo:before-frame-render->ui--sheet-page--component#render click->ui--sheet-page--component#guard:capture',
    }
  end
end
