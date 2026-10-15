class Ui::TurboModal::Component < ViewComponent::Base
  # This component is based on:
  # https://www.bearer.com/blog/how-to-build-modals-with-hotwire-turbo-frames-stimulusjs
  # and
  # https://bhserna.com/remote-modals-with-rails-hotwire-and-bootstrap.html
  #
  # A request of the modal frame shows the page in a BottomSheet, any other
  # request as a plain page.

  renders_one :title

  include Turbo::FramesHelper

  def initialize(title: nil, width: :wide)
    super()
    @title = title
    @width = width
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
      data: {
        ui__turbo_modal__component_target: 'dialog',
        action: 'turbo:submit-end->ui--turbo-modal--component#submitEnd',
      },
    )
  end
end
