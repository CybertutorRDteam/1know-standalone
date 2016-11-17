class DraftKnowledge < ActiveRecord::Base
    self.table_name = 'draft_knowledge'


    has_many :chapters, -> { order "priority ASC" }, :class_name => 'DraftChapter', :foreign_key => :ref_know_id
    has_many :units, -> { order "priority ASC" }, :class_name => 'DraftUnit', :foreign_key => :ref_know_id
    has_many :editors, -> { order "id ASC" }, :class_name => 'DraftKnowledgeEditor', :foreign_key => :ref_know_id

	# code string (0)
	# description string (0)
	# is_public boolean
	# last_update datetime
	# logo string (0)
	# name string (0)
	# release_time datetime
	# total_time decimal
	# uqid string (32)
end
