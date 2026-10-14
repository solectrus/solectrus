# UI building blocks

The `Ui::` components give the phone a look and a behavior like iOS. The desktop keeps the usual web layout: tables, modals and buttons with icons. A page that uses these components shows the phone layout below the `lg` breakpoint and the desktop layout from `lg` up.

## Components

- `Ui::TitleBar`: The title bar of a page on a phone: the title, a round back button and an optional action button at the right. A form page has its save button there. From `lg` up it hides itself.
- `Ui::TableRow`: A row of a desktop table and a cell of an iOS list on a phone. A click anywhere in the row opens its entry.
- `Ui::SegmentedControl`: A segmented control of iOS above a list: pages of the same level side by side, made from hashes like `Ui::NavList`. It has the look of the toggle on the car page.
- `Ui::NavList`: A list of pages one level down in the inset grouped style of iOS: rows on a card with round corners, made from hashes with `:name`, `:href` and `:icon`.
- `Ui::FormPage`: The form of one list entry: in a modal on the desktop, on a page of its own on a phone.
- `Ui::SubmitButton`: The save button of a form on the desktop, with a check mark and a label. A phone has it in the `Ui::TitleBar`. Optional delete button and `label:`.
- `Ui::AddButton`: The round button for a new entry of a list on the desktop. It opens the form in the modal. A phone has the action of the `Ui::TitleBar` instead.

Each component file starts with a comment that describes its parameters and slots.

## Drill-down navigation

A drill-down is a hierarchy of pages, like the settings: a list of sections, and below it a page for each section. On a phone, a page one level down slides in from the right. The way back slides it out to the right. When the entry before the page in the browser history is the parent, the back button goes back to that entry and adds no new one. So the back button of Android leads to the page above, not to the page that you left. If the browser animates a back gesture itself, like Chrome on Android, the page changes at once and does not slide.

The slide needs two things:

1. The page renders a `Ui::TitleBar` with `back_href`, the path of its parent page.
2. The link to the page carries `data-nav-title`, the title of the next page. A row of `Ui::NavList` or `Ui::TableRow` and the action of a `Ui::TitleBar` set it. For a link of your own, use `Ui::TitleBar::Component.link_data(title)`.

The desktop has no slide. There the hover of a row shows that it is a link, so the chevron of a row shows only on a phone.

The header below the title bar can hold more controls of the page, like the timeframe of the charging sessions. Give their container the class `ui-title-bar-accessory`. These controls belong to their page, as on iOS. When a tap slides to the next page, they leave the header, and the header takes the height of the next page during the slide. On the way back, the header grows again when the page arrives.

## Forms

On a phone, a form looks like the iOS settings. Each group of fields is a white card on a gray page. Each field is a cell: the label at the left, the input at the right, without a border. A hint shows below the input, in the same cell. A check box is a switch. The desktop keeps the usual form.

A form gets this look from two things:

1. The form has the class `ui-form`. The form of a list entry gets it from `form_page_with`, see below.
2. The fields lie in a `f.group` of `TailwindFormBuilder`. Each group is one card.

`f.group(stacked: true)` puts each label above its input. Use it when the labels are too long to share a line with the input, like the names of the sensors. A text area shows its name as the placeholder instead of a label, as the notes of an event on iOS. The label stays for a screen reader.

A wrapper that arranges fields on the desktop, like a grid, gets the class `ui-form-contents`. On a phone, the wrapper steps aside, and its fields become cells of the group. `app/frontend/stylesheets/ui_form.css` holds the rules.

`Ui::SubmitButton` follows the layout. On the desktop the buttons stand in a row of their own at the right edge. There the save button has a check mark, a label and the look of the primary `Button::Component`, and the delete button is an icon alone at the left edge. On a phone, the save button is a round check mark at the right of the title bar, as on iOS. The delete button is a red line below the fields.

## Lists with entries

A list of entries, like the prices or the payments, follows one pattern. You can see it in `app/views/settings/prices` and `app/views/settings/cash_flows`.

The index page renders the list once, in a Turbo frame that a stream refreshes:

```slim
= tag.turbo_frame id: 'list', target: '_top' do
  = render PriceList::Component.new(prices: @prices, name:)
```

The list is a table on the desktop and a list in the style of iOS on a phone, see "One row for both layouts". Each row opens the form, in the modal frame on the desktop and on a page of its own on a phone. The `+` button for a new entry is the action of the `Ui::TitleBar` on a phone and a `Ui::AddButton` on the desktop.

Each row is a `Ui::TableRow`. A click anywhere in the row opens the form, so the row has no edit button. One cell puts `row.link` around the main value of the row, like the date or the name. The keyboard and screen readers reach the form through this link. A click on another link of the row, or a click that ends a text selection, does not open the form. Such a link is a target of its own. While the pointer is on it, the row does not light up. A row has no buttons, because each action on the entry is in its form.

The `edit` and `new` views render the form in a `Ui::FormPage`. The component finds out from the request where it shows the form:

```slim
= render Ui::FormPage::Component.new(title: t('settings.prices.edit')) do
  = render 'form', price: @price
```

The partial `form` builds the form with `form_page_with` of `FormPageHelper`. It takes the same arguments as `form_with`:

```slim
= form_page_with(model: price, url: [:settings, price]) do |f|
  = f.group do
    = f.date_field :starts_at, autofocus: true
  = render Ui::SubmitButton::Component.new
```

`form_page_with` gives the form the class `ui-form`, an id from the record and the `form-dirty` controller, which enables the save button. It also sets where the form submits: in the modal frame, or as a visit that replaces the page in the history. A field with `autofocus: true` takes the focus in the modal only. On a page, iOS would open the keyboard during the slide. For other content that differs between the two places, `form_in_modal?` tells the view where the form is.

On a phone, the save button stands in the title bar, outside the form. The view gives the title bar the id of the form, and the button names the form with its `form` attribute. The `form-dirty` controller finds the button among the elements of the form and enables it. Enter in a field submits with this button, because it is the first submit button of the form. The partial `settings/sub_nav` takes the id as `save:`:

```slim
= render 'settings/sub_nav', title: heading, back_href: list_path, back_label: title, save: form_page_id(@price)
```

A view that renders its own `Ui::TitleBar` calls `bar.with_save(form: form_page_id(@record))`.

The form deletes its entry, too. With `delete_path:`, `Ui::SubmitButton` adds a button that submits the form as a DELETE to that path. In the modal it is a trash icon at the left edge, far from the save button. On a page it is a red line below the fields. An entry that leaves the list in another way, like a charging session that is dismissed, also sets `removal:`, a hash with the `method`, the `label`, the `confirm` question and the `icon` of the button.

The controller includes `FormPageResponse` and defines two methods: `default_list_path`, the list of a form that no list opened, and `list_stream`, the Turbo Stream that refreshes the list. `list_stream` can also return several streams, as the places do.

A list can have more than one address, for example with a filter or a timeframe. Each link of such a list to a form passes `return_to: list_address`. `list_address` (from the concern `ListAddress`) is the address of the list as the browser shows it. A next page of the list loads into a frame with the page in its address, and `list_address` leaves that page out. `form_page_with` keeps `return_to` in a hidden field, so a delete button keeps it too. `list_path` is then `return_to`, or `default_list_path` if no list opened the form. `return_to_params` reads the route and the query of `return_to`. So a save renders the list with the filter or the timeframe of the list that opened the form. The views use `list_path` as the `back_href` of the form page.

After a save or a delete, `respond_with_list` answers in one of two ways, with `notice:` as an optional message of its own:

1. A submit from the modal or from the desktop table gets `list_stream`, which refreshes the list in place.
2. A submit from the page of a phone gets the stream action `back_to`. When the entry before the form in the browser history is the list, the browser goes back to it. The list loads again and slides in from the left, and a later way back does not show it a second time. Otherwise, like after a reload of the form, a visit to `list_path` replaces the form page.

If the record does not save, `respond_with_errors(record)` answers. A Turbo Stream replaces the form with the partial `form`, which gets the record under the name of its model, like `price`. The form stays in the modal or on its page, with its errors. So the `edit` and `new` views render only the page. `respond_to_save(record, saved)` picks one of the two answers, so `create` and `update` take one line each.

## One row for both layouts

Each list renders each row once. The same cells are a row of the table from `lg` up and a cell of an iOS list below. You can see it in `PriceList::Component` and `ChargingSession::Row::Component`.

The row is a `Ui::TableRow`, and its `nav_title:` is the title of the slide. Below `lg`, its link opens the entry on a page of its own, with the slide. From `lg` up, the controller of the row points the link to the modal. It also does so after the screen turns. The row adds a chevron for a phone.

The classes of each cell do the rest. Without a prefix or with `lg:`, they give the column of the table. With `max-lg:`, they place the cell in the grid of the iOS cell. That grid names its columns and its rows, because the chevron takes the last column over all rows. A wrapper with `max-lg:contents` lets its children take places of their own. A link in a cell that is a target of its own on the desktop gets `max-lg:pointer-events-none`, so a tap on a phone opens the entry.

The container of the list is the table from `lg` up and a card below. A list with a part of its own, like the totals of the charging sessions, is a column of cards below `lg`. A part that stands elsewhere on a phone, like these totals above the list, moves there with `max-lg:order-first`.

A list in a Turbo frame that a stream refreshes needs `target: '_top'` on that frame. Else a link in the list loads into the frame, and Turbo loads the whole page again.

## Rules

- Take the structure of iOS, not its physics. Lists, grouped forms, a hierarchy of pages and a title bar work on the web. Gestures, rubber banding, large titles that collapse and swipe actions do not. A web page cannot match them, and each copy shows the gaps that remain.
- Keep the look general for a phone, not a copy of the current version of iOS. Android shows the same pages, and Apple changes the look of iOS every year.
- Do not add features to the drill-down navigation, only fix its bugs. It depends on a value inside Turbo, see `docs/testing.md`.
- Put a component in `Ui::` when it is a general building block of this kind. A component that knows one domain, like prices, stays in its own family and renders `Ui::` components.
- Keep the desktop layout as it is when you add a phone layout. Render the content of a list once, as in "One row for both layouts".
- Write the title of a row, of a title bar and of a button with the words of the user interface. They appear in the slide before the next page loads.
