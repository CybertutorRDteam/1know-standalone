class DraftKnowledgeEditor < ActiveRecord::Base
    self.table_name = 'draft_knowledge_editor'


    belongs_to :knowledge, :class_name => 'DraftKnowledge', :foreign_key => :ref_know_id
    belongs_to :user, :class_name => 'User', :foreign_key => :ref_user_id

	# is_show boolean
	# order integer
	# ref_know_id integer (8)
	# ref_user_id integer (8)
	# role string (0)
	# uqid string (32)
end
