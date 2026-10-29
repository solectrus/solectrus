# The menu item of HELIOS leads here. HeliosCheck asks HELIOS for its URL at
# the click, so the link needs no cache and is never stale.
class HeliosController < ApplicationController
  def show
    redirect_to HeliosCheck.browser_url(request), allow_other_host: true
  end
end
