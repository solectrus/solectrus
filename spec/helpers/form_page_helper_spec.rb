describe FormPageHelper do
  describe '#form_page_with' do
    subject(:form) do
      Nokogiri::HTML
        .fragment(
          helper.form_page_with(model: price, url: '/prices') do |f|
            f.date_field(:starts_at, autofocus: true) + f.text_field(:note)
          end,
        )
        .at('form')
    end

    let(:price) { Price.new(name: :electricity) }

    before { allow(helper).to receive(:form_in_modal?).and_return(modal) }

    context 'when the modal asks for it' do
      let(:modal) { true }

      it 'submits within the modal frame and focuses the field' do
        aggregate_failures do
          expect(form['id']).to eq(helper.dom_id(price, :form))
          expect(form['class']).to eq('ui-form')
          expect(form['data-controller']).to eq('form-dirty')
          expect(form['data-turbo-frame']).to eq('modal')
          expect(form.at('input[type=date]')['autofocus']).to eq('autofocus')
          expect(form.at('input[type=text]')['autofocus']).to be_nil
        end
      end
    end

    context 'when a page asks for it' do
      let(:modal) { false }

      it 'replaces the page in the history and focuses no field' do
        aggregate_failures do
          expect(form['data-turbo-action']).to eq('replace')
          expect(form['data-turbo-frame']).to be_nil
          expect(form.at('input[type=date]')['autofocus']).to be_nil
        end
      end
    end

    context 'with a model in a namespace' do
      let(:modal) { false }

      it 'takes the id from the record' do
        html = helper.form_page_with(model: [:settings, price], url: '/prices') { '' }

        expect(Nokogiri::HTML.fragment(html).at('form')['id']).to eq(helper.dom_id(price, :form))
      end
    end
  end
end
