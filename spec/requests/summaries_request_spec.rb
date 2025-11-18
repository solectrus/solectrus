describe 'Summaries' do
  subject(:request) { get "/summaries/#{date}" }

  let(:date) { Date.parse('2021-07-01') }

  describe 'GET /show' do
    context 'when Summary exists' do
      before { Summary.create!(date:) }

      it 'is successful' do
        request
        expect(response).to have_http_status(:success)
      end

      it "doesn't create a new Summary" do
        expect { request }.not_to change(Summary, :count)
      end
    end

    context 'when Summary does NOT exist' do
      it 'is successful' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'creates a new Summary' do
        expect { request }.to change(Summary, :count).by(1)
        expect(Summary.last.date).to eq(date)
      end
    end
  end

  describe 'DELETE /delete_all' do
    subject(:request) { delete '/summaries' }

    before { Summary.create! date: Date.current }

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'empties the table' do
        expect { request }.to change(Summary, :count).by(-1)
        expect(response).to be_successful
      end
    end

    context 'when not logged in as admin' do
      it 'is forbidden' do
        expect { request }.not_to change(Summary, :count)
        expect(response).to be_forbidden
      end
    end
  end
end
