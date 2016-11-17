class CreateActivationCodes < ActiveRecord::Migration
  def change
    create_table :activation_codes do |t|
      t.string :code  , :limit => 32
      t.string :permission_name
      t.string :role
      t.integer :ref_user_id
      t.integer :duration, :default => 0
      t.datetime :activation_time
      t.timestamps
    end
  end
end
