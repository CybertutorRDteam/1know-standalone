class Group < ActiveRecord::Base
    self.table_name = 'group'


    has_many :knowledges, :class_name => 'GroupKnowledge', :foreign_key => :ref_group_id
    has_many :members, :class_name => 'GroupMember', :foreign_key => :ref_group_id
    has_many :messages, :class_name => 'GroupMessage', :foreign_key => :ref_group_id
    has_many :activities, :class_name => 'GroupActivity', :foreign_key => :ref_group_id

	# code string (0)
	# content string (0)
	# description string (0)
	# file string (0)
	# is_destroyed boolean
	# is_public boolean
	# last_update datetime
	# link string (0)
	# logo string (0)
	# name string (0)
	# uqid string (32)
end
