class CreateKonzesysAccount < ActiveRecord::Migration
  def change
    create_table :konzesys_accounts do |t|
      t.integer "ref_user_id",  limit: 8
      t.text "account"
      t.text "password"
      t.timestamps
    end
  end
end
