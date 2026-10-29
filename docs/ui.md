# UI building blocks

The `Ui::` components are the general building blocks of the interface. They know nothing of the domain of SOLECTRUS, like a sensor or a timeframe. Some of them use parts of the app that belong to the kit, see "Parts outside the namespace".

One group of them gives the phone the layout of an app. The desktop keeps the usual web layout: tables, modals and buttons with icons. A page that uses these components shows the phone layout below the `lg` breakpoint and the desktop layout from `lg` up.

The phone layout takes its patterns from iOS. This document and the code use the names of the patterns, not the name of the platform:

- Grouped list: cells on a white card with round corners, on a gray page.
- Cell: one row of a grouped list, with an optional chevron at the right.
- Segmented control: a row of a few options, with the current one raised.
- Sheet: a panel that slides up from the lower edge of the screen.

A note about iOS in the code describes the browser on iOS, like the zoom into a small text field.

A page has one of two grounds on a phone. A list or a form stands on the gray page of a grouped list, like the settings and the charging sessions. A page of figures and charts stands on white, like the power balance and the car page. Its figures are soft gray tiles, and its chart has no card of its own.

## Components

### Layout of the phone and the desktop

- `Ui::TitleBar`: The title bar of a page on a phone: the title or a logo, a round back button and an optional action button at the right. A form page has its save button there. From `lg` up it hides itself. Its page has the gray background of a grouped list. With `plain: true`, the page keeps its own background, like a page with charts. A page that is no list can stand on the gray as well, like the Top 10. Its view sets `content_for :grouped`.
- `Ui::TableRow`: A row of a desktop table and a cell of a grouped list on a phone. A click anywhere in the row opens its entry. A row without `href` opens nothing and has no chevron, like a row that a visitor may only read.
- `Ui::Chips`: The choices of a filter of the page as a row of chips, all in view, the current one filled, like the cars of the car page on a phone. A row wider than the screen scrolls sideways.
- `Ui::SegmentedControl`: A segmented control above a list: pages of the same level side by side, made from hashes like `Ui::NavList`. With `stretch: true`, it takes the full width on a phone, like the switch in the head of a list. A segment with a `note` has a tiny amber dot after its name, like a list with sessions to review.
- `Ui::GroupedList`: A grouped list, with an optional header above the card and a footer below it. A cell is a link, a button, or a row that holds a control at the right, like a segmented control. A link inside the app shows a chevron, a link to another site an arrow out of a box. With `detail:`, a cell shows a second, smaller line below its name, like the reason why its control is not available. `icon_class:` colors the tile of its icon, like the state of the sponsorship. A cell without a link, an action or a control only shows a state.
- `Ui::NavList`: A grouped list of the pages one level down, made from hashes with `:name`, `:href` and `:icon`.
- `Ui::FormPage`: The form of one list entry: in a modal on the desktop, in a tall sheet on a phone, and on a page of its own without a frame. A form with unsaved changes asks before the sheet closes or a link leaves the page.
- `Ui::SubmitButton`: The save button of a form on the desktop, with a check mark and a label. It shows only while the form has changes, next to a button that discards them. A phone has it in the `Ui::TitleBar`. Optional delete button and `label:`. `Ui::SubmitButton::Component.save_attributes` gives the attributes that every save button needs, also one outside the form.
- `Ui::SaveBar`: The save buttons of a form that the desktop shows on the page, like the system settings. They show at the right of the tabs only while the form has changes, with a button that discards the changes. The other tabs then dim and take no clicks, and a link or a reload asks before it leaves the changes behind. The partial `settings/sub_nav` takes the id of the form as `save_bar:`. A phone has the save button in the `Ui::TitleBar` instead.
- `Ui::ConfirmDialog`: The question before an action, in the middle of the screen instead of the confirm of the browser. The layout renders it once. It answers each `data-turbo-confirm`, see `docs/conventions.md`. A controller asks it through an outlet, like `form-dirty` and the modal before unsaved changes are lost.
- `Ui::AddButton`: The `+` button for a new entry of a list on the desktop. It stands at the right of the header, where a phone has the action of the `Ui::TitleBar`. It opens the form in the modal.

### General

- `Ui::Button`: A link, a button or a submit button with a `label:`, an `icon:` or both. `type:` is `:link`, `:button` or `:submit`, and `style:` is `:primary`, `:secondary` or `:tertiary`. Every other option goes to the element, like `data:` or `title:`.
- `Ui::Popover`: A button that opens a panel below it, like a menu or a few controls without room on a phone. Escape and a click beside the panel close it. With `pick: true` on the panel, a tap on an entry closes it too. The trigger and the panel take the classes of the caller.
- `Ui::Dropdown`: A menu that opens below its button, built on `Ui::Popover`. On a phone it can show a native select instead. Each entry is a `Ui::MenuItem`, a link or a button. The `key:` of an entry names it for the code that builds the menu, like the sensor of a chart. Groups of entries stand in columns, or one below the other with `stacked: true`. With `choices: true`, one dropdown holds several choices, one group for each, and marks the current entry of each group with a check. A native select can mark one entry only, so such a dropdown shows its menu on a phone too, in the look of a menu of iOS. The options of the Top 10 work like this. `look:` names the look of the button: `:default`, `:header` on the colored bar of the header, `:plain` without a background, or `:pill` above a list on the gray page of a phone.
- `Ui::BottomSheet`: A sheet on a phone, a dialog in the middle of the screen from `md` up. `app/frontend/utils/bottomSheet.ts` opens and closes it.
- `Ui::TurboModal`: The modal of the frame `modal`. A request of this frame shows the page in a `Ui::BottomSheet`, any other request shows it as a plain page. A form with unsaved changes asks in `Ui::ConfirmDialog` before the modal closes. A link opens its page in the modal with `data: Ui::TurboModal::Component.link_data`, and `link_data(tooltip: true)` for a link with a tooltip.
- `Ui::Flash`: The message after an action, like "Saved". It slides in at the lower edge of the screen and goes away after two seconds.
- `Ui::Message`: A page for a message, like an error page, with slots for a symbol, a title, a text and a footer.
- `Ui::EmptyState`: The place of a list, a map or a chart without content: an icon in a circle, a title and an optional text. It fills the free height and stands in its center. Every empty state uses it.
- `Ui::FilterBar` and `Ui::FilterLink`: The notice above a filtered list and the chevron in a row that narrows the list. See "Lists with a filter". `Ui::RemoveLink` is the small x of a pill that removes a part of the filter.
- `Ui::Badge`: A short label in a colored pill, like the category of an entry. With `remove_path:`, a `Ui::RemoveLink` follows the label.
- `Ui::Loading`: The animated spinner.
- `Ui::LazyFrame`: A Turbo frame that loads its content in a request of its own and shows `Ui::Loading` until then.
- `Ui::LazyRows`: The rows of one page of a list from Pagy, and a frame that loads the next page when it comes into view. It shows a spinner, and its text is for a screen reader alone.
- `Ui::AmountTable`: A list of amounts with their total, like the cash flows. On the desktop it is a grid with a header that stays at the top. On a phone it is a grouped list, and the total stands in a group of its own. The block gives the rows.
- `Ui::GroupHeader`: The header of a group of rows, with a `title:` and an optional `href:` to the list of the group alone. On a phone it cuts the card into a card per group. `Timeframe::RowGroups`, outside the namespace, puts the rows of a list in groups of a month, a week or a day and gives the title of each group.
- `Ui::OptimisticNav`: The data of a navigation whose marking moves to the tapped item at once, like `Ui::Chips` and `Ui::SegmentedControl`. With `slide: true`, the marking slides there.
- `Ui::InfoIcon`: An info icon with a tooltip, for a sentence that explains a value.

Each component file starts with a comment that describes its parameters and slots.

## Parts outside the namespace

The components use some parts of the app. These parts belong to the kit:

- `config/locales/ui.en.yml` and `ui.de.yml`: The texts that several components share, like "Save". A text of one component alone stays in the yml file beside it.
- `app/components/ui/frames.ts`: The names of the frames `modal` and `sheet-page` and of the parameter `form_sheet`, for the TypeScript side. The Ruby side has them as `Ui::TurboModal::Component::FRAME`, `Ui::SheetPage::Component::FRAME` and `Ui::FormPage::Component::SHEET_PARAM`.
- `FormPageHelper`, `FormPageResponse` and the concern `SheetPage`: They tell `Ui::FormPage` and `Ui::SheetPage` where a form shows, and they answer a save. See "Forms" and "Sheets with pages".
- `ListFilter` and `FilteredList`: The filter that `Ui::FilterBar` and `Ui::FilterLink` show. Both call `filter_path` of the concern. See "Lists with a filter".
- The Stimulus controllers `form-dirty`, `modal-launcher`, `tooltip` and `optimistic-nav` in `app/frontend/controllers`, and `utils/bottomSheet.ts` and `utils/modal.ts`.
- `app/frontend/stylesheets/ui_form.css`: The look of a form on a phone, see "Forms".

The navigation of the app on a phone, with the tab bar and the timeframe of a view, is in `docs/navigation.md`.

## Drill-down navigation

A drill-down is a hierarchy of pages, like the settings: a list of sections, and below it a page for each section. On a phone, a page one level down slides in from the right. The way back slides it out to the right. When the entry before the page in the browser history is the parent, the back button goes back to that entry and adds no new one. So the back button of Android leads to the page above, not to the page that you left. If the browser animates a back gesture itself, like Chrome on Android, the page changes at once and does not slide.

The slide needs two things:

1. The page renders a `Ui::TitleBar` with `back_href`, the path of its parent page.
2. The link to the page carries `data-nav-title`, the title of the next page. A row of `Ui::NavList` or `Ui::TableRow` and the action of a `Ui::TitleBar` set it. For a link of your own, use `Ui::TitleBar::Component.link_data(title)`. If the next page shows a logo or keeps its own background, pass `logo:` or `plain:`, so the slide shows the next page as it comes.

The desktop has no slide. There the hover of a row shows that it is a link, so the chevron of a row shows only on a phone. A cell of a grouped list hides its chevron only for a mouse, because a tablet as wide as a desktop has no hover.

The header below the title bar can hold more controls of the page, like the timeframe of the charging sessions. Give their container the class `ui-title-bar-accessory`. These controls belong to their page. When a tap slides to the next page, they leave the header, and the header takes the height of the next page during the slide. On the way back, the header grows again when the page arrives.

## Sheets with pages

On a phone, the car page opens its lists in a tall sheet: the charging sessions and the places. A tall sheet leaves a small strip of the page above it. It keeps its height while its content changes. `Ui::SheetPage` renders one page of the sheet. Each page has a head with its title, a way back, and actions at the right, like the map and the button for a new entry, or the save button of a form. The main action stands at the very right. From `md` up, the sheet is a dialog in the gray of a page. It has no head of its own, so the first page holds the close button in its head.

The pages of a sheet load into the frame `sheet-page` (see `SheetPage`). The first page loads into the modal frame with the parameter `sheet`. Its links and its forms then stay in the sheet. A tap on an entry opens its form as a page one level down. That page slides in from the right, and the way back slides it out again. The slide starts at the tap, while the page loads. It shows the head of the next page with the `data-nav-title` of the link, or on the way back the list as the sheet left it. After a save, the server sends the sheet back to the list. If the sheet closes after a save, the figures and the charts of the car page load again, so they show the changes.

If a form in the sheet has unsaved changes, a link that leaves it asks first. The sheet asks too before it closes. A drag on a map in the sheet moves the map, not the sheet.

The desktop does not use these sheets. It keeps the lists as pages and the forms in the modal. The lists keep their own pages on a phone too, for a link from another page.

## Forms

On a phone, a form is a grouped list. Each group of fields is a card. Each field is a cell: the label at the left, the input at the right, without a border. A text field puts its label above the input, so the text has the full width of the cell. A hint shows below the input, in the same cell. A check box is a switch. The desktop keeps the usual form.

A form gets this look from two things:

1. The form has the class `ui-form`. The form of a list entry gets it from `form_page_with`, see below.
2. The fields lie in a `f.group` of `TailwindFormBuilder`. Each group is one card.

`f.group(stacked: true)` puts each label above its input. Use it when the labels are too long to share a line with the input, like the names of the sensors. `f.group(footer:)` puts a text below the card. Use it for a long explanation, like the meaning of the categories, which would make the cell too high. A short hint stays in the cell. A text area shows its name as the placeholder instead of a label. The label stays for a screen reader.

A wrapper that arranges fields on the desktop, like a grid, gets the class `ui-form-contents`. On a phone, the wrapper steps aside, and its fields become cells of the group. `app/frontend/stylesheets/ui_form.css` holds the rules.

`Ui::SubmitButton` follows the layout. On the desktop the buttons stand in a row of their own at the right edge. There the save button has a check mark, a label and the look of the primary `Ui::Button`, and the delete button is an icon alone at the left edge. The save button shows only while the form has changes, together with a button that discards them. On a phone, the save button is a round check mark at the right of the title bar. The delete button is a red line below the fields.

## Lists with entries

A list of entries, like the prices or the payments, follows one pattern. You can see it in `app/views/settings/prices` and `app/views/settings/cash_flows`.

The index page renders the list once, in a Turbo frame that a stream refreshes:

```slim
= tag.turbo_frame id: 'list', target: '_top' do
  = render Price::List::Component.new(prices: @prices, name:)
```

The list is a table on the desktop and a grouped list on a phone, see "One row for both layouts". Each row opens the form in the modal frame. The desktop shows it in a modal, a phone in a tall sheet over the list. The `+` button for a new entry is the action of the `Ui::TitleBar` with `sheet: true` on a phone and a `Ui::AddButton` on the desktop.

Each row is a `Ui::TableRow`. A click anywhere in the row opens the form, so the row has no edit button. One cell puts `row.link` around the main value of the row, like the date or the name. The keyboard and screen readers reach the form through this link. A click on another link of the row, or a click that ends a text selection, does not open the form. Such a link is a target of its own. While the pointer is on it, the row does not light up. A row has no buttons, because each action on the entry is in its form.

The `edit` and `new` views render the form in a `Ui::FormPage`. The component finds out from the request where it shows the form. A phone asks with the parameter `form_sheet`, which the row and the `+` button add (see `FormPageHelper#form_sheet?`). `form:` is the id of the form, for the save button in the head of the sheet:

```slim
= render Ui::FormPage::Component.new(title: t('settings.prices.edit'), form: form_page_id(@price)) do
  = render 'form', price: @price
```

The partial `form` builds the form with `form_page_with` of `FormPageHelper`. It takes the same arguments as `form_with`:

```slim
= form_page_with(model: price, url: [:settings, price]) do |f|
  = f.group do
    = f.date_field :starts_at, autofocus: true
  = render Ui::SubmitButton::Component.new
```

`form_page_with` gives the form the class `ui-form`, an id from the record and the `form-dirty` controller, which enables the save button. A form that comes back with errors holds input that is not saved yet. It counts as changed until a save succeeds. On a page, the controller also asks in `Ui::ConfirmDialog` before a link leaves unsaved changes. It asks at the click, before the title bar starts its slide. `form_page_with` also sets where the form submits: in the modal frame, also from the sheet of a phone, or as a visit that replaces the page in the history. A field with `autofocus: true` takes the focus in the modal of the desktop only. In the sheet or on a page, iOS would open the keyboard at once. For other content that differs between the places, `form_in_modal?` and `form_sheet?` tell the view where the form is.

On a phone, the save button stands in the head of the sheet, outside the form. The button names the form with its `form` attribute. The `form-dirty` controller finds the button among the elements of the form and enables it. Enter in a field submits with this button, because it is the first submit button of the form. On a page of its own, the save button stands in the title bar. The partial `settings/sub_nav` takes the id as `save:`:

```slim
= render 'settings/sub_nav', title: heading, back_href: list_path, back_label: title, save: form_page_id(@price)
```

A view that renders its own `Ui::TitleBar` calls `bar.with_save(form: form_page_id(@record))`.

The form deletes its entry, too. With `delete_path:`, `Ui::SubmitButton` adds a button that submits the form as a DELETE to that path. In the modal it is a trash icon at the left edge, far from the save button. In the sheet and on a page of a phone, it is a red line below the fields.

The controller includes `FormPageResponse` and defines two methods: `default_list_path`, the list of a form that no list opened, and `list_stream`, the Turbo Stream that refreshes the list. `list_stream` can also return several streams, as the places do.

A list can have more than one address, for example with a filter or a timeframe. Each link of such a list to a form passes `return_to: list_address`. `list_address` (from the concern `ListAddress`) is the address of the list as the browser shows it. A next page of the list loads into a frame with the page in its address, and `list_address` leaves that page out. `form_page_with` keeps `return_to` in a hidden field, so a delete button keeps it too. `list_path` is then `return_to`, or `default_list_path` if no list opened the form. `return_to_params` reads the route and the query of `return_to`. So a save renders the list with the filter or the timeframe of the list that opened the form. The views use `list_path` as the `back_href` of the form page.

After a save or a delete, `respond_with_list` answers in one of two ways, with `notice:` as an optional message of its own:

1. A submit from the modal, from the sheet of a phone or from the desktop table gets `list_stream`, which refreshes the list in place. The modal or the sheet then closes.
2. A submit from a page of its own gets the stream action `back_to`. When the entry before the form in the browser history is the list, the browser goes back to it. The list loads again and slides in from the left, and a later way back does not show it a second time. Otherwise, like after a reload of the form, a visit to `list_path` replaces the form page.

If the record does not save, `respond_with_errors(record)` answers. A Turbo Stream replaces the form with the partial `form`, which gets the record under the name of its model, like `price`. The form stays in the modal or on its page, with its errors. So the `edit` and `new` views render only the page. `respond_to_save(record, saved)` picks one of the two answers, so `create` and `update` take one line each.

## Lists with a filter

A filter narrows a list, for example the cash flows, to some categories and a range of dates. Three parts make it:

1. `ListFilter`: A `Data` with the members `categories`, `from` and `to` includes this module. It reads the filter from the query of the list, applies it to a scope and gives the filter with another value, like `with_year(date)` or `without_category(category)`. A filter can add members of its own.
2. `FilteredList`: The controller includes this concern and names the filter with `filters_with CashFlow::Filter`. The concern gives `filter` and `filter_path(other)`, the address of the list with another filter. A form takes the filter of the list that opened it, and the session remembers the filter of the index.
3. `Ui::FilterBar` shows each part of the filter as a pill. The small x of a pill removes this part alone, and a link clears the whole filter. The bar takes the component of a category pill, and a member of its own adds a pill with `with_pill`. In a row, `Ui::FilterLink` is a chevron beside a value that narrows the list to it. It does not show when it would not change the filter.

The bar has no controls to compose a filter, because the links of the list set it. It stands outside the frame of the list, so a refresh of the list keeps it.

## One row for both layouts

Each list renders each row once. The same cells are a row of the table from `lg` up and a cell of a grouped list below. You can see it in `Price::List::Component` and `ChargingSession::Row::Component`.

The row is a `Ui::TableRow`. Below `lg`, its link opens the entry on a page of its own, with `nav_title:` as the title of the slide. With `form_sheet: true`, it opens the form of the entry in a sheet instead, like the lists of the settings. From `lg` up, the controller of the row points the link to the modal. It also does so after the screen turns. The row adds a chevron for a phone.

The classes of each cell do the rest. Without a prefix or with `lg:`, they give the column of the table. With `max-lg:`, they place the cell in the grid of the cell. That grid names its columns and its rows, because the chevron takes the last column over all rows. A wrapper with `max-lg:contents` lets its children take places of their own. A link in a cell that is a target of its own on the desktop gets `max-lg:pointer-events-none`, so a tap on a phone opens the entry.

The container of the list is the table from `lg` up and a card below. A list with a part of its own, like the totals of the charging sessions, is a column of cards below `lg`. A part that stands elsewhere on a phone, like these totals above the list, moves there with `max-lg:order-first`.

A list in a Turbo frame that a stream refreshes needs `target: '_top'` on that frame. Else a link in the list loads into the frame, and Turbo loads the whole page again.

## Rules

- Take the structure of iOS, not its physics. Lists, grouped forms, a hierarchy of pages and a title bar work on the web. Gestures, rubber banding, large titles that collapse and swipe actions do not. A web page cannot match them, and each copy shows the gaps that remain.
- Keep the look general for a phone, not a copy of the current version of iOS. Android shows the same pages, and Apple changes the look of iOS every year.
- Do not add features to the drill-down navigation, only fix its bugs. It depends on a value inside Turbo, see `docs/testing.md`.
- Put a component in `Ui::` when another app could use it as it is. A component that knows SOLECTRUS, like the list of prices, stays in its own family and renders `Ui::` components.
- Keep the desktop layout as it is when you add a phone layout. Render the content of a list once, as in "One row for both layouts".
- Write the title of a row, of a title bar and of a button with the words of the user interface. They appear in the slide before the next page loads.
