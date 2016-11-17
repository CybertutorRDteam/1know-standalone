class Chapter < ActiveRecord::Base
    self.table_name = 'chapter'


    belongs_to :knowledge, :class_name => 'Knowledge', :foreign_key => :ref_know_id

    has_many :units, -> { order "priority ASC" },  :class_name => 'Unit', :foreign_key => :ref_chapter_id

	# is_destroyed boolean
	# last_update datetime
	# name string (0)
	# priority integer
	# ref_know_id integer (8)
	# uqid string (0)
end
