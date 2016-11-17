class DraftChapter < ActiveRecord::Base
    self.table_name = 'draft_chapter'


    belongs_to :knowledge, :class_name => 'DraftKnowledge', :foreign_key => :ref_know_id
    
    has_many :units, -> { order "priority ASC" }, :class_name => 'DraftUnit', :foreign_key => :ref_chapter_id

	# last_update datetime
	# name string (0)
	# priority integer
	# ref_know_id integer (8)
	# release_time datetime
	# uqid string (0)
end
