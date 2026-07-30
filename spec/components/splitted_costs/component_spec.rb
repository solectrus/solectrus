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

    context 'with breakdown' do
      # Simulates rounding issue: 0.154 + 0.014 = 0.168
      # Without fix: displayed as 0.15 + 0.01 = 0.16, but total shows 0.17
      # With fix: total = 0.15 + 0.01 = 0.16
      let(:grid_costs) { 0.154 }
      let(:pv_costs) { 0.014 }
      let(:costs) { 0.168 }

      it 'calculates total from rounded parts' do
        expect(component.costs).to eq(0.16)
      end
    end

    # Money loses its decimals from 10 upwards, so the parts have to be rounded
    # the same way -- otherwise 43 plus 12 shows up as 56
    context 'with parts large enough to lose their decimals' do
      let(:grid_costs) { 43.28 }
      let(:pv_costs) { 12.35 }
      let(:costs) { 55.63 }

      it 'calculates total from the parts as displayed' do
        expect(component.costs).to eq(55)
      end
    end
  end
end
