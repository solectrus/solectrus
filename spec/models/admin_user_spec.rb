describe AdminUser do
  describe 'validations' do
    subject(:admin_user) { described_class.new(params) }

    context 'with valid params' do
      let(:params) do
        {
          username: 'admin',
          password: Rails.application.config.x.admin_password,
        }
      end

      it { is_expected.to be_valid }
    end

    context 'with invalid password' do
      let(:params) { { username: 'admin', password: 'invalid' } }

      it { is_expected.not_to be_valid }
    end

    context 'with invalid username' do
      let(:params) do
        { username: 'foo', password: Rails.application.config.x.admin_password }
      end

      it { is_expected.not_to be_valid }
    end

    context 'when ADMIN_PASSWORD is not configured' do
      before do
        allow(Rails.configuration.x).to receive(:admin_password).and_return(nil)
      end

      let(:params) { { username: 'admin', password: 'anything' } }

      it { is_expected.not_to be_valid }
    end
  end
end
