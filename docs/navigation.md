# Navigation on a phone

This document describes the navigation of the app on a phone: the tab bar, the page More and the timeframe of a view. `docs/ui.md` describes the components behind it, like `Ui::TitleBar` and `Ui::Chips`.

## The tab bar and the page More

A phone has a tab bar at its lower edge. Its navigation starts with the views of the energy: the balance, the house, the heat pump, the car, the generation and the forecast. All views but the forecast share the timeframe. The other pages follow, like the Top 10.

The tab bar holds the first four entries, the primary entries. If a system has fewer than four views, other pages take the free places. The last tab opens the page More. It lists the secondary entries, which do not fit into the tab bar, in one group, the views first.

A view on the page More stays a tab. It shows no title bar, and the tab More stays marked. The page More has no timeframe of its own, so its links open the views in their default timeframe.

The other secondary entries, like the Top 10, stand on their own, like a tab. The layout gives each of them a `Ui::TitleBar` with its name but without a back button, and a tap on the page More opens it without a slide. The notifications are one level below the page More, so their title bar leads back there. A page that the tab bar holds shows no title bar. The comparison with a combustion car stands in a group of its own on the page More. It slides in, and its title bar leads back to the car page.

The switches of the page More, like the language, slide their marking to the new choice, as the tab bar does. The `segment-slide` controller does this for radios and for buttons.

## The timeframe of a view on a phone

Below a wide screen in landscape, a view shows its timeframe in two rows. The header holds the tabs: the live view, the day, the week, the month, the year and the whole time. The tabs between the first and the last show their initial only. The content starts with the period (`Timeframe::Pager`): its name between two arrows. The tabs pick the kind of period, and the arrows turn it.

A tap on the name opens the timeframe select in a sheet, with the picker of the period already open. Its way back shows the fields of the select. A chevron beside the name marks this. The arrows turn the page, as a swipe does. From today, they lead to yesterday and to the forecast. An arrow without a page in its direction stays dimmed in its place.

The live view shows no period. Its arrows stay in the page, hidden, because the swipe takes its pages from them. So a swipe on the live view leads to yesterday and to the forecast. A comparison of the years shows no period either, because the menu of its tab picks the comparison.

The lists of the car have no tabs. Their period stands at the top of the list, below the title bar. On the car page and on its lists, the cars follow below the period as chips (`Ui::Chips`). On the forecast, the period names the next days. Its tabs, the arrow back to today and its timeframe select belong to the view that led to the forecast. The desktop keeps the tabs and the timeframe with its arrows in the header.

In the timeframe select, each field of a day, a week, a month and a year has two buttons. The first selects the period that it shows. The chevron opens the picker for another one. On the forecast, the select marks the forecast and none of the fields.

On a phone, the select fits without scrolling. Each field is a tile with its name above it, in two columns. The period and its chevron join as one split button. The range and the forecast share the third row. Below the tiles, the windows back from now form one grid, and each window shows its unit. The whole time follows, in years and in months, with the names of the menu on the wide screen. The comparisons of the years stand at the bottom. The tile of a week names its year only when that is not the current year.

Fullscreen is a mode of the document, and Turbo keeps the document from page to page. The page More turns it on with a switch, and the page that the user opens next shows in fullscreen. The menu of the desktop lies over the page, so it keeps its two items to enter and to leave fullscreen.
