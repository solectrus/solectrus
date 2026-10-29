# The menu item of HELIOS leads here. HeliosCheck asks HELIOS for its URL at
# the click, so the link needs no cache and is never stale.
#
# Without an answer of HELIOS, the click leads to its installation. The
# cache can hold "no HELIOS" for a day, like after a start of the dashboard
# before HELIOS, so the click asks again.
class HeliosController < ApplicationController
  INSTALL_URLS = {
    de: 'https://solectrus.de/install/',
    en: 'https://solectrus.de/install/en/',
  }.freeze
  private_constant :INSTALL_URLS

  def show
    target = HeliosCheck.version(cached: false) ? HeliosCheck.browser_url(request) : install_url

    redirect_to target, allow_other_host: true
  end

  private

  def install_url
    SolectrusLink.url(
      INSTALL_URLS.fetch(I18n.locale, INSTALL_URLS[:en]),
      campaign: 'main-nav',
      content: 'helios',
    )
  end
end
