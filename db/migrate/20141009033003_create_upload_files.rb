class CreateUploadFiles < ActiveRecord::Migration
  def change
    create_table :upload_files do |t|
      t.integer "ref_user_id"
      t.text "file_name"
      t.string  "uqid",  limit: 32
      t.timestamps
    end
  end
end
