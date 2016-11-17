class DraftUnit < ActiveRecord::Base
    self.table_name = 'draft_unit'


    belongs_to :knowledge, :class_name => 'DraftKnowledge', :foreign_key => :ref_know_id
    belongs_to :chapter, :class_name => 'DraftChapter', :foreign_key => :ref_chapter_id
    
    has_many :questions, -> { order "q_no ASC" }, :class_name => 'DraftQuestion', :foreign_key => :ref_unit_id

	# content string (0)
	# content_time decimal
	# content_url string (0)
	# create_time datetime
	# is_preview boolean
	# last_update datetime
	# name string (0)
	# priority integer
	# ref_chapter_id integer (8)
	# ref_know_id integer (8)
	# release_time datetime
	# supplementary_description string (0)
	# unit_type string (0)
	# uqid string (32)
end
