# Menu items for the previews of Nav::Top and Nav::Bottom, in the shape that
# MainNavigation gives them. Every link goes nowhere.
module NavPreviewItems
  # The first page shows the logo instead of its icon.
  PAGES = {
    balance: 'house',
    inverter: 'solar-panel',
    house: 'house-crack',
    essentials: 'grip',
    top10: 'trophy',
    amortization: 'sack-dollar',
  }.freeze
  private_constant :PAGES

  module_function

  def primary(current: 0)
    PAGES.each_with_index.map do |(page, icon), index|
      {
        name: I18n.t("layout.#{page}"),
        icon:,
        icon_only: true,
        href: '#',
        current: index == current,
      }
    end
  end

  def secondary(helios_dot: false, unread: 0)
    [
      { name: I18n.t('layout.helios'), icon: 'sun', href: '#', dot: helios_dot },
      {
        name: I18n.t('layout.notifications'),
        icon: 'message',
        href: '#',
        badge_count: unread,
      },
      { component: LocaleSelector::Component },
      { name: '-' },
      { name: I18n.t('layout.login'), icon: 'arrow-right-to-bracket', href: '#' },
    ]
  end
end
