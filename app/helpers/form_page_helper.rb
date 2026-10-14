# What differs for the form of a list entry between its two places, see
# Ui::FormPage::Component.
module FormPageHelper
  # The desktop asks for the form from the modal frame, and the form submits
  # within it. The page of a phone asks without a frame.
  def form_in_modal?
    turbo_frame_request?
  end

  # The form of a list entry, with the look of the iOS settings on a phone
  # (see ui_form.css), whose groups TailwindFormBuilder builds. The id lets a
  # stream replace the form when it comes back with errors (see
  # FormPageResponse), and the form-dirty controller enables
  # Ui::SubmitButton::Component.
  #
  # A field with `autofocus: true` takes the focus in the modal only. On a
  # page, iOS would open the keyboard or a picker right at the slide (see
  # TailwindFormBuilder).
  #
  #   = form_page_with(model: price, url: [:settings, price]) do |f|
  def form_page_with(model:, **, &)
    form_with(
      model:,
      id: form_page_id(model),
      builder: TailwindFormBuilder,
      form_page: true,
      html: { class: 'ui-form', data: { controller: 'form-dirty', **form_page_target } },
      **,
      &
    )
  end

  # The id of the form of a list entry. The save button in the title bar of a
  # phone names the form by it (see Ui::TitleBar::Component).
  def form_page_id(model) = dom_id(Array(model).last, :form)

  # In the modal, a form submits within that frame, so the controller can
  # tell the two places apart (see FormPageResponse). On its page, a redirect
  # replaces the form in the history, so the way back skips it. Another form
  # of the page, like a button_to, takes the same data.
  def form_page_target
    form_in_modal? ? { turbo_frame: 'modal' } : { turbo_action: 'replace' }
  end
end
