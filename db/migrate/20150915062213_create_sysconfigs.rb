class CreateSysconfigs < ActiveRecord::Migration
  def change
    create_table :sysconfigs do |t|
      t.string :target, null: false
      t.string :name
      t.text :content
      t.integer :ref_admin_accounts_id, null: false
      t.timestamps
    end
  end
end
