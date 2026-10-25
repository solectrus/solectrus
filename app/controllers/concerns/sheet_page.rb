# A page that a phone shows in a high sheet over the page it belongs to, like
# the charging sessions over the car page (see Ui::SheetPage::Component). A
# link loads it with `sheet` into the modal frame. In the sheet, its links and
# forms load into the frame of the sheet, so the sheet stays while its page
# changes, and a save leads back to the list in the sheet (see
# FormPageResponse).
module SheetPage
  extend ActiveSupport::Concern

  private

  def sheet_page?
    turbo_frame_request_id == Ui::SheetPage::Component::FRAME ||
      (turbo_frame_request_id == Ui::TurboModal::Component::FRAME && params.key?(:sheet))
  end
end
