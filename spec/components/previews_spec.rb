# Renders every scenario of every Lookbook preview, so a preview that no longer
# matches the API of its component fails here instead of in the browser.
describe 'Component previews', type: :component do # rubocop:disable RSpec/DescribeClass
  ViewComponent::Preview.all.sort_by(&:name).each do |preview|
    describe preview.name do
      preview.examples.each do |example|
        it "renders #{example}" do
          expect { render_preview(example, from: preview) }.not_to raise_error
        end
      end
    end
  end
end
