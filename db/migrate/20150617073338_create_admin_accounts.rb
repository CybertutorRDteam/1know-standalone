class CreateAdminAccounts < ActiveRecord::Migration
  def change
    create_table :admin_accounts do |t|
      t.string :account, limit: nil, null: false
      t.string :password, limit: nil, null: false
      t.string :acc_name
      t.timestamps
    end
  end
end
