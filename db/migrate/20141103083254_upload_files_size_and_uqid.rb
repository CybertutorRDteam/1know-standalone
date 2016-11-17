class UploadFilesSizeAndUqid < ActiveRecord::Migration
  def change
  	change_table(:upload_files, :bulk => true) do |t|
	  t.text "file_size"
	  t.text "file_ext"
	  t.text "file_type"
	end
  end
end
