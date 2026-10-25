# The message after an action, like "Saved". It slides in at the lower edge
# of the screen and goes away after two seconds (see component_controller.ts).
# A notice is green, an alert is red. A screen reader reads the message, an
# alert at once.
#
#   = render Ui::Flash::Component.new(notice: 'Saved')
class Ui::Flash::Component < ViewComponent::Base
  KINDS = {
    notice: {
      role: 'status',
      icon: 'circle-check',
      background: 'bg-emerald-50 dark:bg-emerald-800 border-emerald-500 dark:border-emerald-600',
      text: 'text-emerald-800 dark:text-emerald-300',
    },
    alert: {
      role: 'alert',
      icon: 'circle-exclamation',
      background: 'bg-red-50 dark:bg-red-800 border-red-500 dark:border-red-600',
      text: 'text-red-700 dark:text-red-200',
    },
  }.freeze
  private_constant :KINDS

  def initialize(alert: nil, notice: nil)
    super()
    @text = notice || alert
    @kind = KINDS[notice ? :notice : :alert]
  end

  attr_reader :text

  def render? = text.present?

  def role = @kind[:role]

  def icon_name = @kind[:icon]

  def background_class = @kind[:background]

  def text_class = @kind[:text]
end
