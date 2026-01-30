describe RadialBadge::Component, type: :component do
  let(:data) do
    Sensor::Data::Single.new(
      { autarky: percent_value, battery_soc: battery_value },
      timeframe: Timeframe.now,
    )
  end

  context 'with autarky sensor' do
    subject(:component) { described_class.new(:autarky, data:) }

    context 'when percent is 0' do
      let(:percent_value) { 0 }
      let(:battery_value) { nil }

      before { render_inline(component) }

      it 'renders component with text' do
        expect(page).to have_css '.badge', text: '0%'
      end
    end

    context 'when percent is low (18%)' do
      let(:percent_value) { 18 }
      let(:battery_value) { nil }

      before { render_inline(component) }

      it 'renders component with text' do
        expect(page).to have_css '.badge', text: '18%'
      end
    end

    context 'when percent is medium (50%)' do
      let(:percent_value) { 50 }
      let(:battery_value) { nil }

      before { render_inline(component) }

      it 'renders component with text' do
        expect(page).to have_css '.badge', text: '50%'
      end
    end

    context 'when percent is high (80%)' do
      let(:percent_value) { 80 }
      let(:battery_value) { nil }

      before { render_inline(component) }

      it 'renders component with text' do
        expect(page).to have_css '.badge', text: '80%'
      end
    end

    context 'without percent' do
      let(:percent_value) { nil }
      let(:battery_value) { nil }

      before { render_inline(component) }

      it 'renders component with neutral border' do
        expect(page).to have_css '.badge.border-slate-200'
      end
    end
  end

  context 'with battery_soc sensor' do
    subject(:component) { described_class.new(:battery_soc, data:) }

    context 'when percent is 0% (critical)' do
      let(:percent_value) { nil }
      let(:battery_value) { 0 }

      before { render_inline(component) }

      it 'renders component with red border' do
        expect(page).to have_css '.badge.border-red-200', text: '0%'
      end
    end

    context 'when percent is 4% (critical)' do
      let(:percent_value) { nil }
      let(:battery_value) { 4 }

      before { render_inline(component) }

      it 'renders component with red border' do
        expect(page).to have_css '.badge.border-red-200', text: '4%'
      end
    end

    context 'when percent is 10% (low)' do
      let(:percent_value) { nil }
      let(:battery_value) { 10 }

      before { render_inline(component) }

      it 'renders component with orange/yellow border' do
        expect(page).to have_css '.badge.border-orange-200', text: '10%'
      end
    end

    context 'when percent is 50% (good)' do
      let(:percent_value) { nil }
      let(:battery_value) { 50 }

      before { render_inline(component) }

      it 'renders component with green border' do
        expect(page).to have_css '.badge.border-emerald-200', text: '50%'
      end
    end
  end
end
