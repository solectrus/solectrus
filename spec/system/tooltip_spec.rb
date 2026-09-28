describe 'Tooltip' do
  # One tooltip element serves the whole page and keeps what the tooltip before
  # it wrote. Its arrow must sit at the edge of the box that it points away
  # from, on whichever side the placement puts it.
  it 'keeps the arrow at the edge when the placement changes' do
    visit '/inverter_power/now'
    expect(page).to have_css('#segment-inverter_power')

    # The navigation puts its tooltip below itself, where the arrow hangs on
    # the upper edge and travels from left to right
    first('a[aria-label="Prognose"]').hover
    expect(page).to have_css(".floating-tooltip.show[data-placement^='bottom']")
    expect(arrow_distance_from('top')).to be < 2

    # The right column of the balance points its tooltips to the left, so the
    # arrow moves to another edge and follows the other axis
    find_by_id('segment-house_power').hover
    expect(page).to have_css(".floating-tooltip.show[data-placement^='left']")
    expect(arrow_distance_from('right')).to be < 2
  end

  # iOS turns a popover into a sheet on a compact screen, and so does a
  # tooltip that a touch opens on a phone
  context 'with a touch screen' do
    before { driven_by :playwright_touch }

    it 'shows the tooltip in a bottom sheet' do
      visit '/inverter_power/now'
      add_tap_tooltip('Hint of the probe')

      find_by_id('probe').click
      expect(page).to have_css(
        'dialog#tooltip-sheet[open]',
        text: 'Hint of the probe',
      )
      expect(page).to have_no_css('.floating-tooltip.show')

      # The sheet covers the navigation, so it names the period itself
      expect(page).to have_css(
        'dialog#tooltip-sheet .bottom-sheet-caption',
        text: 'Aktuell',
      )

      # A phone shows no close button, the sheet goes on a swipe or Escape
      find('dialog#tooltip-sheet').send_keys(:escape)
      expect(page).to have_no_css('dialog#tooltip-sheet[open]')
    end

    # The version names itself in the caption, it has no period
    it 'shows the caption of the tooltip instead of the period' do
      visit '/inverter_power/now'
      add_tap_tooltip('Hint of the probe', sheet_caption: 'v1.2.3')

      find_by_id('probe').click
      expect(page).to have_css(
        'dialog#tooltip-sheet[open] .bottom-sheet-caption',
        exact_text: 'v1.2.3',
      )
    end

    # Content with a title names the period below it, as the insights do
    it 'shows the period below the title of the content' do
      visit '/inverter_power/now'
      add_tap_tooltip(
        nil,
        html:
          '<div class="tooltip-layout"><div class="tooltip-header">' \
          '<div class="tooltip-heading"><div class="tooltip-title">Title</div>' \
          '</div></div></div>',
      )

      find_by_id('probe').click
      expect(page).to have_css(
        'dialog#tooltip-sheet[open] .tooltip-title + .tooltip-period',
        exact_text: 'Aktuell',
      )
      expect(page).to have_no_css('dialog#tooltip-sheet .bottom-sheet-caption')
    end

    # A segment of the balance opens its insights, which hold its values
    it 'opens the page of a sheet URL in the modal instead' do
      visit '/inverter_power/now'
      add_tap_tooltip(
        'Hint of the probe',
        sheet_url: '/insights/inverter_power/2025-01',
      )

      find_by_id('probe').click
      expect(page).to have_css('dialog#modal-sheet[open] .insights')
      expect(page).to have_no_css('dialog#tooltip-sheet[open]')
    end
  end

  # A tooltip that opens on a tap, independent of the data a page shows
  def add_tap_tooltip(hint, sheet_url: nil, sheet_caption: nil, html: nil)
    page.execute_script(<<~JS, hint, sheet_url, sheet_caption, html)
      const probe = document.createElement('span');
      probe.id = 'probe';
      probe.textContent = 'Probe';
      if (arguments[0]) probe.title = arguments[0];
      probe.dataset.controller = 'tooltip';
      probe.dataset.tooltipTouchValue = 'true';
      if (arguments[1]) probe.dataset.tooltipSheetUrlValue = arguments[1];
      if (arguments[2]) probe.dataset.sheetCaption = arguments[2];
      if (arguments[3]) {
        const content = document.createElement("template");
        content.dataset.tooltipTarget = "html";
        content.innerHTML = arguments[3];
        probe.append(content);
      }
      document.querySelector('main').prepend(probe);
    JS
  end

  # How far the center of the arrow stands from one edge of the box, in pixels.
  # The arrow reaches a new place over a transition, so in the frame that
  # changes the placement it still stands at the old one.
  def arrow_distance_from(edge)
    page.evaluate_async_script(<<~JS, edge)
      const [edge, done] = arguments;

      requestAnimationFrame(() =>
        requestAnimationFrame(() => {
          const box = document
            .querySelector('.floating-tooltip-inner')
            .getBoundingClientRect();
          const arrow = document
            .querySelector('.floating-tooltip-arrow')
            .getBoundingClientRect();
          const center =
            edge === 'top'
              ? arrow.top + arrow.height / 2
              : arrow.left + arrow.width / 2;

          done(Math.abs(center - box[edge]));
        }),
      );
    JS
  end
end
