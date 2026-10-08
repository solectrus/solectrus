# The gate of the lists and the frames below the car page. They follow the
# car page (see Sensor::HomePage): the settings can switch it off, and a
# sponsorship opens it. Only the admin gets them. A frame answers nothing,
# like SponsoredFrame, and a list goes elsewhere (see CarListPage).
module CarPageGate
  extend ActiveSupport::Concern

  included do
    before_action :verify_car_page
    before_action :admin_required!
  end

  private

  def verify_car_page
    return if Sensor::HomePage.open?(:cars)

    car_page_closed
  end

  def car_page_closed = head(:not_found)
end
