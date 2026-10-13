# The answer to saving or deleting a list entry, whose form comes in two
# places (see Ui::FormPage::Component). The controller defines `list_path`,
# the way back to the list, and `list_stream`, the Turbo Stream (or several)
# that refreshes the list in place.
module FormPageResponse
  extend ActiveSupport::Concern

  private

  # The modal and the list of the desktop submit within their frame, and the
  # stream refreshes the list. The page of a phone goes back to the list, which
  # slides in from the left: the stream action back_to returns to the entry of
  # the list in the history (see setupBackTo.ts). The list shows the notice
  # when it loads. Without Turbo Streams, a redirect leads to the list.
  def respond_with_list(notice: t('crud.success'))
    if turbo_frame_request?
      flash.now[:notice] = notice
      render turbo_stream: [*list_stream, turbo_stream_update_flash]
    elsif request.format.turbo_stream?
      flash[:notice] = notice
      render turbo_stream: turbo_stream.action(:back_to, list_path)
    else
      redirect_to list_path, notice:, status: :see_other
    end
  end

  # A save answers with the list, or with the form and its errors
  def respond_to_save(record, saved)
    saved ? respond_with_list : respond_with_errors(record)
  end

  # A form with errors stays where it is, in the modal or on its page: a
  # stream replaces it with its partial `form`, which takes the record under
  # the name of its model (see FormPageHelper#form_page_with). Without Turbo
  # Streams, the page of the form renders again.
  def respond_with_errors(record)
    unless request.format.turbo_stream?
      return render(record.new_record? ? :new : :edit, status: :unprocessable_content)
    end

    render turbo_stream: turbo_stream.replace(
             helpers.form_page_id(record),
             partial: 'form',
             locals: { record.model_name.element.to_sym => record },
           ),
           status: :unprocessable_content
  end
end
