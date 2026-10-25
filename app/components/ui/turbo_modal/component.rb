# The modal of the frame `modal`. A request of this frame shows the page in a
# Ui::BottomSheet::Component, any other request shows it as a plain page with
# the title as its heading. The layout holds the empty frame, and a link
# loads into it with the data of `.link_data`.
#
# The sheet closes after a successful submit of a form inside it, and its
# controller asks in Ui::ConfirmDialog::Component before a form with unsaved
# changes closes. `width` and `tall`, see Ui::BottomSheet::Component.
#
#   = link_to 'Edit', edit_price_path(price), data: Ui::TurboModal::Component.link_data
#
#   = render Ui::TurboModal::Component.new(title: 'Edit price') do
#     = render 'form', price:
#
# Based on:
# https://www.bearer.com/blog/how-to-build-modals-with-hotwire-turbo-frames-stimulusjs
# https://bhserna.com/remote-modals-with-rails-hotwire-and-bootstrap.html
class Ui::TurboModal::Component < ViewComponent::Base
  FRAME = 'modal'.freeze
  public_constant :FRAME

  # The data of a link that opens its page in the modal. The modal-launcher
  # controller dims the page at the click, while the frame loads. A link
  # with a tooltip names the tooltip controller beside it.
  def self.link_data(tooltip: false, **data)
    { turbo_frame: FRAME, controller: [('tooltip' if tooltip), 'modal-launcher'].compact.join(' '), **data }
  end

  renders_one :title

  def initialize(title: nil, width: :wide, tall: false)
    super()
    @title = title
    @width = width
    @tall = tall
  end

  # The title as a text or as a slot
  def heading
    @title || title
  end

  # The controller asks in Ui::ConfirmDialog::Component before a form with
  # unsaved changes closes
  def modal_data
    {
      controller: 'ui--turbo-modal--component',
      ui__turbo_modal__component_ui__confirm_dialog__component_outlet: Ui::ConfirmDialog::Component::SELECTOR,
    }
  end

  def sheet
    Ui::BottomSheet::Component.new(
      id: 'modal-sheet',
      width: @width,
      tall: @tall,
      data: {
        ui__turbo_modal__component_target: 'dialog',
        action: 'turbo:submit-end->ui--turbo-modal--component#submitEnd',
      },
    )
  end
end
