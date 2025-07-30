describe Loading::Component, type: :component do
  it 'renders SVG' do
    expect(render_inline(described_class.new).css('svg').to_html).to include(
      'viewBox',
    )
  end
end
