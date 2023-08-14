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
  end
end
