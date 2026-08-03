describe ActionCable do
  # The test environment uses the `test` adapter, so the adapters configured for
  # the other environments are never loaded by the suite. An incompatible client
  # gem (like redis 6, which Action Cable does not support) would therefore only
  # blow up in production, on the first broadcast.
  %w[development production].each do |env|
    context "with the #{env} configuration" do
      let(:adapter) { Rails.application.config_for(:cable, env:)[:adapter] }

      it 'loads the configured pubsub adapter' do
        expect do
          require "action_cable/subscription_adapter/#{adapter}"
        end.not_to raise_error
      end
    end
  end
end
