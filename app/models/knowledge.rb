class Knowledge < ActiveRecord::Base
    self.table_name = 'knowledge'


    belongs_to :draft_knowledge, :class_name => 'DraftKnowledge', :foreign_key => :uqid

    has_many :readers, :class_name => 'Reader', :foreign_key => :ref_know_id
    has_many :group_knowledges, :class_name => 'GroupKnowledge', :foreign_key => :ref_know_id
    has_many :chapters, -> { order "priority ASC" }, :class_name => 'Chapter', :foreign_key => :ref_know_id
    has_many :units, -> { order "priority ASC" }, :class_name => 'Unit', :foreign_key => :ref_know_id

	# code string (0)
	# description string (0)
	# is_destroyed boolean
	# is_public boolean
	# last_update datetime
	# logo string (0)
	# name string (0)
	# total_time decimal
	# uqid string (32)
end
