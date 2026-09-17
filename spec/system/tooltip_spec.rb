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
