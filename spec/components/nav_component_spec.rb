require 'rails_helper'

describe NavComponent, type: :component do
  it 'renders menu' do
    items = [
      [ 'one', '/one' ],
      [ 'two', '/two' ]
    ]

    expect(
      render_inline(described_class.new(items: items)).css('a').to_html
    ).to include(
      'href="/one"',
      'href="/two"'
    )
  end
end
