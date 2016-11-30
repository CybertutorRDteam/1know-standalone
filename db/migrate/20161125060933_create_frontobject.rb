class CreateFrontobject < ActiveRecord::Migration
  def change
	create_table :frontobject do |t|
		t.string :name, null: false
		t.text :description
		t.text :knowledges
		t.string :bImg
		t.string :sImg
		t.boolean :bTag, :default => false
		t.timestamps
	end
  end
end
