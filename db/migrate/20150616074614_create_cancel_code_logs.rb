class CreateCancelCodeLogs < ActiveRecord::Migration
  def change
    create_table :cancel_code_logs do |t|
      t.string :old_code
      t.string :new_code
      t.string :permission_name
      t.string :role
      t.timestamps
    end
  end
end