describe SplittedCosts::Component, type: :component do
  subject(:component) do
    described_class.new(costs:, power_grid_ratio:, grid_costs:, pv_costs:, note:)
  end

  let(:costs) { 12.34 }
  let(:power_grid_ratio) { 50 }
  let(:grid_costs) { nil }
  let(:pv_costs) { nil }
  let(:note) { nil }

  it 'renders' do
    render_inline(component)

    expect(page).to have_text '50 %'
    expect(page).to have_text '12 €'
  end

  it 'marks costs as negative (red)' do
    render_inline(component)

    expect(page).to have_css('.sensor-total-costs.text-signal-negative')
  end

  # The battery has a grid share worth showing, but no costs of its own
  context 'without costs' do
    let(:costs) { nil }

    it 'still renders the ratio' do
      render_inline(component)

      expect(page).to have_text '50 %'
    end

    it 'renders no costs at all' do
      render_inline(component)

      expect(page).to have_no_css('.sensor-total-costs')
      expect(page).to have_no_text '–'
    end

    context 'with a note' do
      let(:note) { 'Billed on discharge' }

      it 'explains where the costs went' do
        render_inline(component)

        expect(page).to have_text 'Billed on discharge'
      end
    end
  end

  context 'with two cost halves' do
    let(:grid_costs) { 1.45 }
    let(:pv_costs) { 1.52 }
    let(:costs) { 2.97 }

    before { render_inline(component) }

    it 'names both rows' do
      expect(page).to have_text 'Grid costs'
      expect(page).to have_text 'Opportunity costs'
      expect(page).to have_text 'Economic costs'
    end

    context 'with a German locale' do
      around { |example| I18n.with_locale(:de) { example.run } }

      it 'names them too' do
        expect(page).to have_text 'Netzbezugskosten'
        expect(page).to have_text 'Entg. Einspeisevergütung'
        expect(page).to have_text 'Wirtschaftliche Kosten'
      end
    end
  end

  describe '#costs' do
    context 'without breakdown' do
      it 'returns original costs' do
        expect(component.costs).to eq(12.34)
      end
    end

    # Rounded on their own, the parts show 2,32 and 3,50 -- 5,82 in sum,
    # while the key figure shows 5,83. The missing cent goes to the last part,
    # the rest of the total.
    context 'with parts that round away from the total' do
      let(:grid_costs) { 2.323 }
      let(:pv_costs) { 3.504 }
      let(:costs) { 5.827 }

      it 'keeps the total of the key figure' do
        expect(component.costs).to eq(5.83)
      end

      it 'rounds the parts to add up to it' do
        expect([component.grid_costs, component.pv_costs]).to eq([2.32, 3.51])
      end
    end

    # Money loses its decimals from 10 upwards. When all amounts are that
    # large, total and parts show whole amounts.
    context 'with amounts large enough to lose their decimals' do
      let(:grid_costs) { 43.28 }
      let(:pv_costs) { 12.35 }
      let(:costs) { 55.63 }

      it 'rounds total and parts to whole amounts that add up' do
        expect(component.precision).to eq(0)
        expect([component.grid_costs, component.pv_costs]).to eq([43.0, 13.0])
        expect(component.costs).to eq(56)
      end
    end
  end
end
