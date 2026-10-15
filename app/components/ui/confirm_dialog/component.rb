# The dialog that asks before an action, instead of the confirm of the
# browser. The layout renders it once, and its controller fills in the
# question and the label of the confirm button. It answers every
# data-turbo-confirm and the question of the form-dirty controller.
#
# The element that asks takes its data from Ui::ConfirmDialog::Component.data:
#
#   data: Ui::ConfirmDialog::Component.data(t('settings.places.make_home_confirm'), button: t('confirm.make_home'))
class Ui::ConfirmDialog::Component < ViewComponent::Base
  ID = 'confirm-dialog'.freeze
  public_constant :ID

  # The outlet of a controller that asks, like form-dirty
  SELECTOR = "##{ID}".freeze
  public_constant :SELECTOR

  # The data attributes of an element that asks: the question, the label of
  # the confirm button, and whether the action removes something, which
  # shows the button in red
  def self.data(question, button:, destructive: false)
    { turbo_confirm: question, confirm_button: button, confirm_destructive: (true if destructive) }.compact
  end

  # The question before a delete
  def self.delete_data
    data(I18n.t('crud.confirm_delete'), button: I18n.t('confirm.delete'), destructive: true)
  end
end
