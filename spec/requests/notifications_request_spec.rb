describe 'Notifications' do
  let!(:notification) do
    Notification.create!(
      title: 'Test Notification',
      body: '<p>Test body</p>',
      published_at: 1.day.ago,
    )
  end

  describe 'GET /notifications' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get '/notifications'
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get '/notifications'
        expect(response).to have_http_status(:success)
      end

      it 'displays the notification' do
        get '/notifications'
        expect(response.body).to include('Test Notification')
      end

      context 'when no notifications exist' do
        before { Notification.delete_all }

        it 'redirects to root' do
          get '/notifications'
          expect(response).to redirect_to(root_path)
        end
      end
    end
  end

  describe 'GET /notifications/:id' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        get "/notifications/#{notification.id}"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http success' do
        get "/notifications/#{notification.id}"
        expect(response).to have_http_status(:success)
      end

      it 'displays the notification content' do
        get "/notifications/#{notification.id}"
        expect(response.body).to include('Test body')
      end

      context 'when notification does not exist' do
        it 'redirects to index' do
          get '/notifications/999999'
          expect(response).to redirect_to(notifications_path)
        end
      end
    end
  end

  describe 'PATCH /notifications/:id/mark_as_read' do
    context 'when not logged in' do
      it 'returns http forbidden' do
        patch "/notifications/#{notification.id}/mark_as_read"
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when logged in as admin' do
      before { login_as_admin }

      it 'returns http no_content' do
        patch "/notifications/#{notification.id}/mark_as_read"
        expect(response).to have_http_status(:no_content)
      end

      it 'marks the notification as read' do
        expect do
          patch "/notifications/#{notification.id}/mark_as_read"
        end.to change { notification.reload.read? }.from(false).to(true)
      end

      context 'when notification does not exist' do
        it 'redirects to index' do
          patch '/notifications/999999/mark_as_read'
          expect(response).to redirect_to(notifications_path)
        end
      end
    end
  end
end
