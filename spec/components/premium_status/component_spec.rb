describe PremiumStatus::Component, type: :component do
  subject(:component) { described_class.new }

  let(:html) { render_inline(component).to_html }

  before do
    allow(PremiumStatus).to receive_messages(
      reason: nil,
      ends_at: nil,
      trial_available?: false,
      unknown?: false,
    )
  end

  # Whatever the state, the sidebar ends with one box.
  it 'always renders a box' do
    expect(html).to include('bg-amber-100')
  end

  context 'when in the intro phase' do
    before do
      allow(PremiumStatus).to receive_messages(
        reason: :intro,
        ends_at: 2.days.from_now,
      )
    end

    it 'names the phase and the days left, in one line' do
      expect(html).to include('Trial period')
      expect(html).to include('2 days left')
    end

    # A phase that ends must say so. Otherwise the user learns about the end by
    # losing the features.
    it 'says what the phase gives, and what stays after it' do
      expect(html).to include('All features')
      expect(html).to include('basic features remain afterwards')
    end

    # A first installation gets these days in silence. The free month exists,
    # and the user must not learn about it here - it would be burnt on days that
    # are free anyway.
    it 'says nothing about the free month' do
      expect(html).not_to include('free month')
    end

    it 'stays green, nothing is wrong here' do
      expect(html).to include('bg-emerald-100')
    end

    # Slim splits a class written as .mt-0.5 into "mt-0" and "5".
    it 'keeps fractional spacing classes intact' do
      expect(html).to include('mt-0.5')
    end

    # The update server keeps the offer back during the phase, but an admin
    # session must not conjure one either.
    context 'with an admin session' do
      before { allow(vc_test_controller).to receive(:admin?).and_return(true) }

      it 'asks for nothing' do
        expect(html).to include('Trial period')
        expect(page).to have_no_link
      end
    end
  end

  # The local default. Claiming a grant here would be a lie.
  context 'when running locally' do
    before { allow(PremiumStatus).to receive(:reason).and_return(:development) }

    it 'names the real reason, in gray' do
      expect(html).to include('Development mode')
      expect(html).to include('bg-gray-100')
    end
  end

  context 'when sponsoring' do
    before { allow(PremiumStatus).to receive(:reason).and_return(:sponsoring) }

    # A sponsor knows what the sponsorship gives. Thanks are the better use of
    # the second line here.
    it 'thanks the sponsor' do
      expect(html).to include('Sponsorship is active')
      expect(html).to include('Thank you for your support!')
      expect(html).to include('bg-emerald-100')
    end
  end

  # The update server can add a grant, and it reaches this app before the
  # release that knows the name. Such a grant must not read as a locked
  # installation - it is the opposite of one.
  context 'when the grant has a name this release does not know' do
    before do
      allow(PremiumStatus).to receive_messages(
        reason: :lifetime,
        ends_at: 3.days.from_now,
      )
    end

    it 'says what the user has, and asks for nothing' do
      expect(html).to include('All features')
      expect(html).to include('bg-emerald-100')
      expect(html).not_to include('No active sponsorship')
    end

    it 'still counts down, because the answer carries the end' do
      expect(html).to include('3 days left')
    end
  end

  context 'when eligible for free' do
    before do
      allow(PremiumStatus).to receive(:reason).and_return(:eligible_for_free)
    end

    it 'says what it means' do
      expect(html).to include('Approved for free use')
      expect(html).to include('bg-emerald-100')
    end
  end

  context 'when no premium applies' do
    context 'with the free trial still unused' do
      before do
        allow(PremiumStatus).to receive(:trial_available?).and_return(true)
      end

      context 'with an admin' do
        before do
          allow(vc_test_controller).to receive(:admin?).and_return(true)
        end

        it 'offers the free trial' do
          expect(html).to include('No active sponsorship')
          expect(html).to include('Start the free month')
          expect(html).not_to include('Become a sponsor')
        end
      end

      # Only an admin can start the month, so anyone else gets the one call to
      # action they can follow.
      context 'without an admin session' do
        it 'asks for a sponsorship instead' do
          expect(html).not_to include('Start the free month')
          expect(html).not_to include('/registration')
          expect(html).to include('Become a sponsor')
        end
      end
    end

    context 'with the free trial used up' do
      it 'asks for a sponsorship' do
        expect(html).to include('No active sponsorship')
        expect(html).to include('Become a sponsor')
        expect(html).not_to include('Start the free month')
      end
    end
  end

  # Both states lock the features, but only one of them is an answer. Asking a
  # sponsor for a sponsorship because the network is down is the worse of the
  # two errors.
  context 'when the update server cannot be reached' do
    before { allow(PremiumStatus).to receive(:unknown?).and_return(true) }

    it 'names the outage instead of a missing sponsorship' do
      expect(html).to include('Status unknown')
      expect(html).to include('update server cannot be reached')
      expect(html).not_to include('No active sponsorship')
    end

    it 'asks for nothing, because nothing can be done about it' do
      expect(html).to include('bg-gray-100')
      expect(page).to have_no_link
    end

    # The offer belongs to an answered "no", not to a missing answer.
    context 'with the free trial still unused' do
      before do
        allow(vc_test_controller).to receive(:admin?).and_return(true)
        allow(PremiumStatus).to receive(:trial_available?).and_return(true)
      end

      it 'still names the outage' do
        expect(html).to include('Status unknown')
        expect(html).not_to include('Start the free month')
      end
    end
  end

  # The registration has its own banner above the page.
  context 'when the registration is still missing' do
    before do
      allow(UpdateCheck).to receive_messages(
        unregistered?: true,
        registration_reminder_due?: true,
      )
    end

    it 'says nothing about it' do
      expect(html).not_to include('Registration required')
      expect(html).not_to include('Not registered')
    end
  end

  # A scenario only names the keys it needs, and the template renders whatever
  # it finds. A typo would therefore not fail, it would silently drop the icon
  # or the link - so the structure is checked here instead.
  describe 'the locale files' do
    subject(:de) { scenarios('de') }

    let(:known_keys) { %w[title description icon countdown cta_text cta_link] }

    def scenarios(locale)
      file = "app/components/premium_status/component.#{locale}.yml"
      YAML.load_file(Rails.root.join(file))[locale]
    end

    it 'names no key the template does not render' do
      expect(de).to be_present
      de.each_value { |scenario| expect(scenario.keys - known_keys).to be_empty }
    end

    # Two lines everywhere: the title names the reason, the description says
    # what it means for the user.
    it 'gives every scenario a title, a description and an icon' do
      de.each_value do |scenario|
        expect(scenario.keys).to include('title', 'description', 'icon')
      end
    end

    it 'keeps both locales in step' do
      en = scenarios('en')

      expect(en.keys).to eq(de.keys)
      de.each { |name, scenario| expect(en[name].keys).to eq(scenario.keys) }
    end

    # A reason without a scenario would render an empty box.
    it 'covers every reason this component knows' do
      described_class::KNOWN_REASONS.each do |reason|
        expect(de.keys).to include(reason.to_s)
      end
    end
  end
end
