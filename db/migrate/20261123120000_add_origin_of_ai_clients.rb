# An AI client writes over MCP what the admin enters in the forms: prices,
# payments and offsite charging sessions. Each entry says who wrote it last,
# the admin or an AI client, so the admin can check the entries of a client.
#
# The default `user` keeps the existing entries, and those that an older
# version writes, as written by the admin. A charging session already has an
# origin, which gets `mcp` as a value beside `user` and `detection`.
#
# A payment also keeps the number of the document it comes from, like the
# number of a bill. The number finds the entry of a document again, so it is
# unique per kind of payment.
class AddOriginOfAiClients < ActiveRecord::Migration[8.1]
  def up
    add_column :prices, :origin, :string, null: false, default: 'user'

    change_table :payments, bulk: true do |t|
      t.string :origin, null: false, default: 'user'
      t.string :reference
      t.index %i[type reference], unique: true, where: 'reference IS NOT NULL'
    end

    change_table :cash_flows, bulk: true do |t|
      t.string :origin, null: false, default: 'user'
      t.string :reference
      t.index :reference, unique: true, where: 'reference IS NOT NULL'
    end

    # An offsite session of an AI client needs the same as one of the user:
    # it is assigned
    replace_user_constraint "origin NOT IN ('user', 'mcp') OR kind = 'offsite' AND assigned_manually"
  end

  # The sessions of an AI client become sessions of the user, because the
  # old constraint knows no other origin of an entered session
  def down
    execute "UPDATE charging_sessions SET origin = 'user' WHERE origin = 'mcp'"
    replace_user_constraint "origin <> 'user' OR kind = 'offsite' AND assigned_manually"

    change_table(:cash_flows, bulk: true) { it.remove :reference, :origin }
    change_table(:payments, bulk: true) { it.remove :reference, :origin }
    remove_column :prices, :origin
  end

  private

  def replace_user_constraint(expression)
    remove_check_constraint :charging_sessions, name: 'charging_sessions_user'
    add_check_constraint :charging_sessions, expression, name: 'charging_sessions_user'
  end
end
