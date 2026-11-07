# The payments of the heat pump: everything it costs or earns, by category
# (see Heatpump::Payment and PaymentSettings), like the payments of the cars.
# The comparison with a fossil heating counts some of them. The page is a tab
# beside the heating. A filter of categories and of a range of dates narrows
# the list (see Heatpump::PaymentFilter).
class Settings::HeatpumpPaymentsController < ApplicationController
  include SettingsNavigation
  include PaymentSettings

  filters_with Heatpump::PaymentFilter

  private

  def payment_class = Heatpump::Payment

  # Only the comparison counts the payments, so they need it
  def comparison_required! = heatpump_settings_required!
end
