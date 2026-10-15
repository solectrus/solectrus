# What differs for the form of a list entry between its two places, see
# Ui::FormPage::Component, and the data of a form that the desktop shows on
# the page.
module FormPageHelper
  # The desktop asks for the form from the modal frame, and the form submits
  # within it. The page of a phone asks without a frame.
  def form_in_modal?
    turbo_frame_request?
  end

  # The form of a list entry, as a grouped list on a phone
  # (see ui_form.css), whose groups TailwindFormBuilder builds. The id lets a
  # stream replace the form when it comes back with errors (see
  # FormPageResponse), and the form-dirty controller enables
  # Ui::SubmitButton::Component. On its page, the form asks before a visit
  # leaves its changes behind. In the modal, the modal asks.
  #
  # A field with `autofocus: true` takes the focus in the modal only. On a
  # page, iOS would open the keyboard or a picker right at the slide (see
  # TailwindFormBuilder).
  #
  # The form keeps the list that opened it (see FormPageResponse). A field
  # carries it, not the address of the form, because a delete button
  # replaces that address.
  #
  #   = form_page_with(model: price, url: [:settings, price]) do |f|
  def form_page_with(model:, **, &)
    form_with(
      model:,
      id: form_page_id(model),
      builder: TailwindFormBuilder,
      form_page: true,
      html: { class: 'ui-form', data: { **(form_in_modal? ? { controller: 'form-dirty' } : page_form_data), **form_page_target } },
      **,
    ) do |f|
      safe_join([(hidden_field_tag(:return_to, return_to, id: nil) if return_to), capture(f, &)])
    end
  end

  # The data of a form on a page and not in the modal, like the general
  # settings. The form-dirty controller asks in
  # Ui::ConfirmDialog::Component before a visit leaves the changes behind.
  #
  #   = form_with(url: settings_general_path, html: { data: page_form_data }) do |f|
  def page_form_data
    {
      controller: 'form-dirty',
      form_dirty_ui__confirm_dialog__component_outlet: Ui::ConfirmDialog::Component::SELECTOR,
    }
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
