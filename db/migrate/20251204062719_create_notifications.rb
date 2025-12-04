class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.string :title, null: false
      t.text :body, null: false
      t.datetime :published_at, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, :published_at
    add_index :notifications, :id, where: 'read_at IS NULL', name: 'index_notifications_on_unread'
  end
end
