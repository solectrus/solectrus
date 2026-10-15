class TurboModal::Component < ViewComponent::Base
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
      controller: 'turbo-modal--component',
      turbo_modal__component_ui__confirm_dialog__component_outlet: Ui::ConfirmDialog::Component::SELECTOR,
    }
  end

  def sheet
    BottomSheet::Component.new(
      id: 'modal-sheet',
      width: @width,
      data: {
        turbo_modal__component_target: 'dialog',
        action: 'turbo:submit-end->turbo-modal--component#submitEnd',
      },
    )
  end
end
